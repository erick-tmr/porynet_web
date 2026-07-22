#!/usr/bin/env python3
"""Compare two yellow_maps.json manifests and report, per map, which markers moved.

The golden test in tests/test_manifest.py proves the committed manifest still matches the game
data; it cannot say *which* maps a generator change shifted. This does, so a fix for one map that
silently drags another along is visible in the PR instead of in production.

  python tools/maps/manifest_diff.py <base.json> <head.json>
"""
import json
import sys
from dataclasses import dataclass, field

POSITION_KEYS = ("grid", "x", "y")


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


if __name__ == "__main__":  # pragma: no cover
    base, head = (json.loads(open(path).read()) for path in sys.argv[1:3])
    print(render_markdown(diff_manifests(base, head)))
