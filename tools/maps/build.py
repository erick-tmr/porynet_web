#!/usr/bin/env python3
"""Render every walkthrough image from pokeyellow and emit the manifest the Rails app consumes.

Two input sources:
  - the location tables in locations.py -> one plain area map per walkthrough location,
    shown in the location header.
  - declarative JSON specs under tools/maps/specs/*.json -> annotated maps, NPC maps, overworld
    dialog scenes (e.g. the hidden-item "found" shot), and battle scenes. See generators.py for
    the spec schema; positions are grid coordinates.

Usage:
  python tools/maps/build.py --pokeyellow ~/Code/pokeyellow [--force]

Outputs (relative to the porynet_web repo root):
  app/assets/images/walkthrough/yellow/{maps,scenes,battles}/<name>.png   (gitignored -> R2)
  app/models/walkthrough/yellow_maps.json                                 manifest (committed)
  tools/maps/REPORT.md                                                     counts + review notes
"""
import argparse
import json
import pathlib

import compositor
import generators
import locations
import markers
import roster
import sources

REPO = pathlib.Path(__file__).resolve().parents[2]
IMG_ROOT = REPO / "app/assets/images/walkthrough/yellow"
SPECS_DIR = pathlib.Path(__file__).resolve().parent / "specs"
MANIFEST = REPO / "app/models/walkthrough/yellow_maps.json"
ROSTER = REPO / "app/models/walkthrough/yellow_trainers.json"
REPORT = pathlib.Path(__file__).resolve().parent / "REPORT.md"

# spec type -> output subdirectory (and R2 key prefix) under walkthrough/yellow/
DIR_BY_TYPE = {"map": "maps", "arrows": "maps", "npc": "maps",
               "dialog": "scenes", "screen": "scenes", "battle": "battles"}

def load_specs():
    specs = []
    for path in sorted(SPECS_DIR.glob("*.json")):
        specs.extend(json.loads(path.read_text()))
    return specs


def save_png(image, subdir, name, force):
    out_dir = IMG_ROOT / subdir
    out_dir.mkdir(parents=True, exist_ok=True)
    png = out_dir / f"{name}.png"
    if force or not png.exists():
        image.save(png)
    return f"walkthrough/yellow/{subdir}/{name}.png"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pokeyellow", required=True)
    ap.add_argument("--force", action="store_true", help="re-render PNGs that already exist")
    ap.add_argument("--palette", choices=["gbc", "sgb", "dmg"], default="gbc",
                    help="hardware color palette: gbc (Game Boy Color, default), "
                         "sgb (Super Game Boy), dmg (original Game Boy greens)")
    args = ap.parse_args()
    root = str(pathlib.Path(args.pokeyellow).expanduser())
    compositor.PALETTE_MODE = args.palette

    headers = sources.parse_headers(root)
    areas, missing = {}, []

    for slug, maps in sorted(locations.location_maps().items()):
        entries = []
        for label, floor, parent in maps:
            if label not in headers:
                missing.append(f"{slug}: {label}")
                continue
            name = locations.image_name(slug, floor)
            image, colors = compositor.render_map(root, label, parent)
            # every map shows its people and its item balls, exactly where the game puts them
            image = compositor.overlay_sprites(
                image, root, generators.auto_npcs(root, label, battlers=True), colors,
                compositor.grass_cells(root, label))
            key = save_png(image, "maps", name, args.force)
            entries.append({"image": key, "width": image.width, "height": image.height,
                            "floor": floor, "name": name,
                            "markers": markers.build_markers(root, label, headers[label][0],
                                                             image.width, image.height)})
        if entries:
            areas[slug] = entries

    trainers, where_specs = roster.build_roster(root)
    for spec in where_specs:
        image, name, _extra = generators.generate(root, spec)
        save_png(image, "scenes", name, args.force)

    step_shots, scenes = {}, {}
    for spec in load_specs():
        label = spec.get("map")
        if label and label not in headers:
            missing.append(f"{spec['name']}: {label}")
            continue
        image, name, extra = generators.generate(root, spec)
        key = save_png(image, DIR_BY_TYPE[spec["type"]], name, args.force)
        entry = {"image": key, "width": image.width, "height": image.height, **extra}
        if spec.get("slug") and spec.get("step") is not None:
            step_shots.setdefault(spec["slug"], {})[str(spec["step"])] = entry
        else:
            scenes[name] = {**entry, "type": spec["type"]}

    MANIFEST.write_text(json.dumps(
        {"source": "pret/pokeyellow", "locations": areas,
         "step_shots": step_shots, "scenes": scenes}, indent=2))
    ROSTER.write_text(json.dumps(
        {"source": "pret/pokeyellow", "count": sum(len(v) for v in trainers.values()),
         "trainers": trainers}, indent=2))
    _write_report(areas, step_shots, scenes, trainers, missing)
    print(f"palette: {args.palette}  "
          f"location maps: {sum(len(v) for v in areas.values())}  "
          f"markers: {_marker_total(areas)}  "
          f"step shots: {sum(len(v) for v in step_shots.values())}  "
          f"scenes: {len(scenes)}+{len(where_specs)}  "
          f"trainers: {sum(len(v) for v in trainers.values())}  missing: {len(missing)}")
    if missing:
        print("MISSING:", ", ".join(missing))


def _marker_total(areas, cat=None):
    return sum(len([m for m in e["markers"] if cat is None or m["cat"] == cat])
               for maps in areas.values() for e in maps)


def _write_report(areas, step_shots, scenes, trainers, missing):
    lines = ["# Asset generation report", "",
             f"- location maps: **{sum(len(v) for v in areas.values())}** across {len(areas)} locations",
             f"- markers: **{_marker_total(areas)}** "
             f"({_marker_total(areas, 'trainer')} trainer, {_marker_total(areas, 'item')} item, "
             f"{_marker_total(areas, 'hidden')} hidden, {_marker_total(areas, 'exit')} exit)",
             f"- step shots: **{sum(len(v) for v in step_shots.values())}** (map/scene in a step slot)",
             f"- standalone scenes: **{len(scenes)}** (dialog / battle / NPC, not step-bound)",
             f"- trainers: **{sum(len(v) for v in trainers.values())}** across {len(trainers)} locations",
             f"- missing map labels: **{len(missing)}**", ""]
    if missing:
        lines += ["## Missing labels", ""] + [f"- {m}" for m in missing] + [""]
    lines += ["## Markers per map", ""]
    for slug, maps in sorted(areas.items()):
        for entry in maps:
            counts = {c: len([m for m in entry["markers"] if m["cat"] == c])
                      for c in ("trainer", "item", "hidden", "exit")}
            summary = ", ".join(f"{n} {c}" for c, n in counts.items() if n)
            lines.append(f"- `{entry['name']}`: {summary or 'none'}")
    lines += ["", "## Step shots", ""]
    for slug, steps in sorted(step_shots.items()):
        for n, s in sorted(steps.items()):
            lines.append(f"- `{slug}` step {n}: {s['image']}")
    lines += ["", "## Scenes", ""]
    for name, s in sorted(scenes.items()):
        lines.append(f"- `{name}` ({s['type']}): {s['image']}")
    REPORT.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
