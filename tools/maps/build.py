#!/usr/bin/env python3
"""Render every walkthrough image from pokeyellow and emit the manifest the Rails app consumes.

Two input sources:
  - the location tables below (`_SIMPLE` / `_GYM_CITIES` / `_DUNGEONS`) -> one plain area map
    per walkthrough location, shown in the location header.
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
import sources

REPO = pathlib.Path(__file__).resolve().parents[2]
IMG_ROOT = REPO / "app/assets/images/walkthrough/yellow"
SPECS_DIR = pathlib.Path(__file__).resolve().parent / "specs"
MANIFEST = REPO / "app/models/walkthrough/yellow_maps.json"
REPORT = pathlib.Path(__file__).resolve().parent / "REPORT.md"

# spec type -> output subdirectory (and R2 key prefix) under walkthrough/yellow/
DIR_BY_TYPE = {"map": "maps", "arrows": "maps", "npc": "maps",
               "dialog": "scenes", "screen": "scenes", "battle": "battles"}

# slug -> ordered [(map_label, floor_label, parent_map_const_or_None)]; parent is only needed for
# interiors that aren't cavern/cemetery (they inherit a town palette).
_SIMPLE = {
    "pallet-town": "PalletTown", "route-1": "Route1", "viridian-city": "ViridianCity",
    "route-22": "Route22", "route-2": "Route2", "viridian-forest": "ViridianForest",
    "route-3": "Route3", "route-4": "Route4", "route-24": "Route24", "route-25": "Route25",
    "route-5": "Route5", "route-6": "Route6", "route-11": "Route11", "route-9": "Route9",
    "route-10": "Route10", "lavender-town": "LavenderTown", "route-8": "Route8", "route-7": "Route7",
    "route-12": "Route12", "route-13": "Route13", "route-14": "Route14", "route-15": "Route15",
    "route-16": "Route16", "route-17": "Route17", "route-18": "Route18", "route-19": "Route19",
    "route-20": "Route20", "power-plant": "PowerPlant", "route-21": "Route21", "route-23": "Route23",
    "indigo-plateau": "IndigoPlateau", "digletts-cave": "DiglettsCave",
}
_GYM_CITIES = {
    "pewter-city": ("PewterCity", "PewterGym", "PEWTER_CITY"),
    "cerulean-city": ("CeruleanCity", "CeruleanGym", "CERULEAN_CITY"),
    "vermilion-city": ("VermilionCity", "VermilionGym", "VERMILION_CITY"),
    "celadon-city": ("CeladonCity", "CeladonGym", "CELADON_CITY"),
    "fuchsia-city": ("FuchsiaCity", "FuchsiaGym", "FUCHSIA_CITY"),
    "saffron-city": ("SaffronCity", "SaffronGym", "SAFFRON_CITY"),
    "cinnabar-island": ("CinnabarIsland", "CinnabarGym", "CINNABAR_ISLAND"),
}


def _floors(base, labels, parent=None):
    return [(f"{base}{s}", s, parent) for s in labels]


_DUNGEONS = {
    "mt-moon": _floors("MtMoon", ["1F", "B1F", "B2F"]),
    "rock-tunnel": _floors("RockTunnel", ["1F", "B1F"]),
    "seafoam-islands": _floors("SeafoamIslands", ["1F", "B1F", "B2F", "B3F", "B4F"]),
    "cerulean-cave": _floors("CeruleanCave", ["1F", "2F", "B1F"]),
    "victory-road": _floors("VictoryRoad", ["1F", "2F", "3F"]),
    "pokemon-tower": _floors("PokemonTower", ["1F", "2F", "3F", "4F", "5F", "6F", "7F"]),
    "silph-co": _floors("SilphCo", ["1F", "2F", "3F", "4F", "5F", "6F", "7F", "8F", "9F", "10F", "11F"], "SAFFRON_CITY"),
    "rocket-hideout": _floors("RocketHideout", ["B1F", "B2F", "B3F", "B4F"], "CELADON_CITY"),
    "pokemon-mansion": _floors("PokemonMansion", ["1F", "2F", "3F", "B1F"], "CINNABAR_ISLAND"),
    "ss-anne": _floors("SSAnne", ["1F", "2F", "3F", "B1F"], "VERMILION_CITY"),
    "safari-zone": [("SafariZoneCenter", "Center", None), ("SafariZoneEast", "East", None),
                    ("SafariZoneNorth", "North", None), ("SafariZoneWest", "West", None)],
    "viridian-gym": [("ViridianGym", "", "VIRIDIAN_CITY")],
}


def location_maps():
    out = {}
    for slug, label in _SIMPLE.items():
        out[slug] = [(label, "", None)]
    for slug, (town, gym, parent) in _GYM_CITIES.items():
        out[slug] = [(town, "", None), (gym, "Gym", parent)]
    out.update(_DUNGEONS)
    return out


def image_name(slug, floor):
    return slug if not floor else f"{slug}-{floor.lower().replace(' ', '-')}"


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
    locations, missing = {}, []

    for slug, maps in sorted(location_maps().items()):
        entries = []
        for label, floor, parent in maps:
            if label not in headers:
                missing.append(f"{slug}: {label}")
                continue
            name = image_name(slug, floor)
            image = compositor.render_map(root, label, parent)[0]
            key = save_png(image, "maps", name, args.force)
            entries.append({"image": key, "width": image.width, "height": image.height, "floor": floor})
        if entries:
            locations[slug] = entries

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
        {"source": "pret/pokeyellow", "locations": locations,
         "step_shots": step_shots, "scenes": scenes}, indent=2))
    _write_report(locations, step_shots, scenes, missing)
    print(f"palette: {args.palette}  "
          f"location maps: {sum(len(v) for v in locations.values())}  "
          f"step shots: {sum(len(v) for v in step_shots.values())}  "
          f"scenes: {len(scenes)}  missing: {len(missing)}")
    if missing:
        print("MISSING:", ", ".join(missing))


def _write_report(locations, step_shots, scenes, missing):
    lines = ["# Asset generation report", "",
             f"- location maps: **{sum(len(v) for v in locations.values())}** across {len(locations)} locations",
             f"- step shots: **{sum(len(v) for v in step_shots.values())}** (map/scene in a step slot)",
             f"- standalone scenes: **{len(scenes)}** (dialog / battle / NPC, not step-bound)",
             f"- missing map labels: **{len(missing)}**", ""]
    if missing:
        lines += ["## Missing labels", ""] + [f"- {m}" for m in missing] + [""]
    lines += ["## Step shots", ""]
    for slug, steps in sorted(step_shots.items()):
        for n, s in sorted(steps.items()):
            lines.append(f"- `{slug}` step {n}: {s['image']}")
    lines += ["", "## Scenes", ""]
    for name, s in sorted(scenes.items()):
        lines.append(f"- `{name}` ({s['type']}): {s['image']}")
    REPORT.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
