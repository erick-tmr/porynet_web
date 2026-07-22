#!/usr/bin/env python3
"""Compare two yellow_maps.json manifests and report, per map, which markers moved.

The golden test in tests/test_manifest.py proves the committed manifest still matches the game
data; it cannot say *which* maps a generator change shifted, and it goes green again the moment
you regenerate, however many maps moved. This says which, and can hold you to a declared set.

A moved marker is usually the point of the change, so "the manifest changed" cannot be the
failure condition. Intent has to come from the author, as a `Manifest-drift:` commit trailer
listing the maps the change is meant to move (or `all` for a wholesale regeneration). Comparing
that against the real set turns collateral damage from a report into a failure.

  python tools/maps/manifest_diff.py <base.json> <head.json>
  python tools/maps/manifest_diff.py <base.json> <head.json> --expect route-22,viridian-city
  git log origin/main..HEAD --format=%B | python tools/maps/manifest_diff.py a.json b.json --expect-commits -
"""
import argparse
import json
import re
import sys
from dataclasses import dataclass, field

POSITION_KEYS = ("grid", "x", "y")
TRAILER = re.compile(r"^[ \t]*Manifest-drift:[ \t]*(.+)$", re.MULTILINE | re.IGNORECASE)
DECLARE_ALL = "all"


@dataclass
class MapDelta:
    name: str
    status: str = "changed"
    added: list = field(default_factory=list)
    removed: list = field(default_factory=list)
    moved: list = field(default_factory=list)
    resized: tuple = None

    def empty(self):
        return not (self.added or self.removed or self.moved or self.resized)


def _entries(manifest):
    return {entry["name"]: entry
            for maps in manifest.get("locations", {}).values() for entry in maps}


def _position(marker):
    return {key: marker.get(key) for key in POSITION_KEYS}


def _describe(marker):
    grid = marker.get("grid")
    where = f"[{grid[0]},{grid[1]}]" if grid else "?"
    return f"`{marker['id']}` {where} {marker.get('name') or marker.get('ref') or ''}".strip()


def _pair_by_identity(old_only, new_only):
    """Match a dropped marker to an added one when they are the same thing at a new position.

    Most marker ids embed their grid anchor (`hidden-48-15`), so a marker that shifts leaves the
    id set entirely. Re-pairing on (cat, ref) turns that remove+add pair back into one move.
    """
    def key(marker):
        return marker["cat"], marker.get("ref")

    moved = []
    old_by_key, new_by_key = {}, {}
    for marker in old_only:
        old_by_key.setdefault(key(marker), []).append(marker)
    for marker in new_only:
        new_by_key.setdefault(key(marker), []).append(marker)
    for identity, olds in old_by_key.items():
        news = new_by_key.get(identity, [])
        if len(olds) == 1 and len(news) == 1:
            moved.append((olds[0], news[0]))
    paired_old = {id(o) for o, _ in moved}
    paired_new = {id(n) for _, n in moved}
    return (moved,
            [m for m in old_only if id(m) not in paired_old],
            [m for m in new_only if id(m) not in paired_new])


def diff_entry(old, new):
    delta = MapDelta(name=new["name"])
    if (old["width"], old["height"]) != (new["width"], new["height"]):
        delta.resized = ((old["width"], old["height"]), (new["width"], new["height"]))

    old_markers = {m["id"]: m for m in old["markers"]}
    new_markers = {m["id"]: m for m in new["markers"]}
    for marker_id in old_markers.keys() & new_markers.keys():
        before, after = old_markers[marker_id], new_markers[marker_id]
        if _position(before) != _position(after):
            delta.moved.append((before, after))

    moved, removed, added = _pair_by_identity(
        [m for i, m in old_markers.items() if i not in new_markers],
        [m for i, m in new_markers.items() if i not in old_markers])
    delta.moved += moved
    delta.removed, delta.added = removed, added
    return delta


def diff_manifests(old, new):
    old_entries, new_entries = _entries(old), _entries(new)
    deltas = []
    for name in sorted(old_entries.keys() | new_entries.keys()):
        if name not in new_entries:
            deltas.append(MapDelta(name=name, status="removed",
                                   removed=old_entries[name]["markers"]))
        elif name not in old_entries:
            deltas.append(MapDelta(name=name, status="added",
                                   added=new_entries[name]["markers"]))
        else:
            delta = diff_entry(old_entries[name], new_entries[name])
            if not delta.empty():
                deltas.append(delta)
    return deltas


def render_markdown(deltas):
    if not deltas:
        return "No map or marker changes: every map in the manifest is byte-identical to `main`."

    lines = [f"**{len(deltas)} map(s) changed.** Confirm this is exactly the set you meant to touch.",
             "", "| Map | Status | Added | Removed | Moved |", "|---|---|---:|---:|---:|"]
    for delta in deltas:
        lines.append(f"| `{delta.name}` | {delta.status} | {len(delta.added)} | "
                     f"{len(delta.removed)} | {len(delta.moved)} |")
    lines.append("")

    for delta in deltas:
        lines.append(f"<details><summary><code>{delta.name}</code> ({delta.status})</summary>")
        lines.append("")
        if delta.resized:
            before, after = delta.resized
            lines.append(f"- resized {before[0]}x{before[1]} -> {after[0]}x{after[1]}")
        for before, after in delta.moved:
            lines.append(f"- moved {_describe(before)} -> {_describe(after)}")
        for marker in delta.added:
            lines.append(f"- added {_describe(marker)}")
        for marker in delta.removed:
            lines.append(f"- removed {_describe(marker)}")
        lines += ["", "</details>", ""]
    return "\n".join(lines)


def parse_names(value):
    """Split a comma or space separated list of map names."""
    return {name.lower() for name in (value or "").replace(",", " ").split()}


def parse_declared(text):
    """Collect the map names from every `Manifest-drift:` trailer in a blob of commit messages."""
    names = set()
    for value in TRAILER.findall(text or ""):
        names |= parse_names(value)
    return names


def check_drift(deltas, declared):
    """Return (moved but undeclared, declared but unmoved). Both empty means the sets agree."""
    moved = {delta.name for delta in deltas}
    if DECLARE_ALL in declared:
        return [], []
    return sorted(moved - declared), sorted(declared - moved)


def render_verdict(undeclared, unmoved):
    if not undeclared and not unmoved:
        return "Declared drift matches the manifest."
    lines = []
    if undeclared:
        lines.append(f"**{len(undeclared)} map(s) moved without being declared:** "
                     + ", ".join(f"`{n}`" for n in undeclared))
        lines.append("")
        lines.append("Either this is collateral damage from your change (fix it), or it is "
                     "intended, in which case add these to the `Manifest-drift:` trailer.")
    if unmoved:
        lines.append(f"**{len(unmoved)} map(s) declared but unchanged:** "
                     + ", ".join(f"`{n}`" for n in unmoved))
        lines.append("")
        lines.append("Your change did not move these. Drop them from the trailer.")
    return "\n".join(lines)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("base")
    parser.add_argument("head")
    parser.add_argument("--expect", default="",
                        help="comma or space separated map names this change is meant to move")
    parser.add_argument("--expect-commits", default=None, metavar="PATH",
                        help="file of commit messages to read Manifest-drift: trailers from "
                             "('-' for stdin)")
    args = parser.parse_args(argv)

    with open(args.base) as base_file, open(args.head) as head_file:
        deltas = diff_manifests(json.load(base_file), json.load(head_file))
    print(render_markdown(deltas))

    if args.expect_commits is None and not args.expect:
        return 0

    declared = parse_names(args.expect)
    if args.expect_commits:
        text = (sys.stdin.read() if args.expect_commits == "-"
                else open(args.expect_commits).read())
        declared |= parse_declared(text)

    undeclared, unmoved = check_drift(deltas, declared)
    listed = ", ".join(f"`{name}`" for name in sorted(declared)) or "none"
    print(f"\n### Declared drift ({listed})\n")
    print(render_verdict(undeclared, unmoved))
    return 1 if undeclared or unmoved else 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
