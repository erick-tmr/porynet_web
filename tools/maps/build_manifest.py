#!/usr/bin/env python3
"""Render every walkthrough-location map from pokeyellow and emit the manifest the
Rails app consumes.

Two kinds of output:
  - area maps: one plain colored map per location (shown in the location header). No markers.
  - step shots: an interior map rendered into a specific walkthrough step's screenshot slot,
    with hand-placed point-of-interest markers (e.g. the bedroom PC for the free Potion).

Usage:
  python tools/maps/build_manifest.py --pokeyellow ~/Code/pokeyellow [--force]

Outputs (relative to the porynet_web repo root):
  app/assets/images/walkthrough/yellow/maps/<name>.png   colored map (gitignored -> R2)
  app/models/walkthrough/yellow_maps.json                manifest (committed)
  tools/maps/REPORT.md                                   counts + anything to review
"""
import argparse
import json
import pathlib

import render_maps

REPO = pathlib.Path(__file__).resolve().parents[2]
IMG_DIR = REPO / "app/assets/images/walkthrough/yellow/maps"
MANIFEST = REPO / "app/models/walkthrough/yellow_maps.json"
REPORT = pathlib.Path(__file__).resolve().parent / "REPORT.md"
R2_PREFIX = "walkthrough/yellow/maps"

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

# maps rendered into a specific walkthrough step's screenshot slot:
#   slug -> {step_n: {map, parent, name, sprites?, arrows?}}
# name is the output basename and must not collide with an area-map slug. sprites composite
# overworld frames for illustration (red.png frame 1 = the player facing up); arrows are
# directional pointers (e.g. toward a map exit). See render_maps for the sprite/arrow specs.
_STEP_SHOTS = {
    "pallet-town": {
        1: {"map": "RedsHouse2F", "parent": "PALLET_TOWN", "name": "reds-house-2f",
            "sprites": [{"sprite": "red", "frame": 1, "grid": [0, 2]}]},
        4: {"map": "PalletTown", "parent": None, "name": "pallet-town-exit",
            "sprites": [{"sprite": "red", "frame": 1, "grid": [10, 2]}],
            "arrows": [{"dir": "up", "px": [168, 18]}]},
    },
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


def render_and_save(root, label, parent, name, force, sprites=None, arrows=None):
    img = render_maps.render_map(root, label, parent, sprites, arrows)
    png = IMG_DIR / f"{name}.png"
    if force or not png.exists():
        img.save(png)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pokeyellow", required=True)
    ap.add_argument("--force", action="store_true", help="re-render PNGs that already exist")
    args = ap.parse_args()
    root = str(pathlib.Path(args.pokeyellow).expanduser())

    headers = render_maps.parse_headers(pathlib.Path(root))  # label -> (const, tileset)
    IMG_DIR.mkdir(parents=True, exist_ok=True)

    locations, missing = {}, []
    for slug, maps in sorted(location_maps().items()):
        entries = []
        for label, floor, parent in maps:
            if label not in headers:
                missing.append(f"{slug}: {label}")
                continue
            name = image_name(slug, floor)
            img = render_and_save(root, label, parent, name, args.force)
            entries.append({"image": f"{R2_PREFIX}/{name}.png", "width": img.width,
                            "height": img.height, "floor": floor})
        if entries:
            locations[slug] = entries

    step_shots = {}
    for slug, steps in sorted(_STEP_SHOTS.items()):
        for step_n, spec in steps.items():
            label = spec["map"]
            if label not in headers:
                missing.append(f"{slug} step {step_n}: {label}")
                continue
            name = spec["name"]
            img = render_and_save(root, label, spec.get("parent"), name, args.force,
                                  spec.get("sprites"), spec.get("arrows"))
            step_shots.setdefault(slug, {})[str(step_n)] = {
                "image": f"{R2_PREFIX}/{name}.png", "width": img.width, "height": img.height}

    MANIFEST.write_text(json.dumps(
        {"source": "pret/pokeyellow", "locations": locations, "step_shots": step_shots}, indent=2))
    _write_report(locations, step_shots, missing)
    print(f"location maps: {sum(len(v) for v in locations.values())}  "
          f"step shots: {sum(len(v) for v in step_shots.values())}  missing: {len(missing)}")
    if missing:
        print("MISSING:", ", ".join(missing))


def _write_report(locations, step_shots, missing):
    lines = ["# Map generation report", "",
             f"- location maps: **{sum(len(v) for v in locations.values())}** across {len(locations)} locations",
             f"- step shots: **{sum(len(v) for v in step_shots.values())}** (interior maps in a step slot)",
             f"- missing map labels: **{len(missing)}**", ""]
    if missing:
        lines += ["## Missing labels", ""] + [f"- {m}" for m in missing] + [""]
    lines += ["## Step shots", ""]
    for slug, steps in sorted(step_shots.items()):
        for n, s in sorted(steps.items()):
            lines.append(f"- `{slug}` step {n}: {s['image']}")
    REPORT.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
