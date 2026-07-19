#!/usr/bin/env python3
"""Render every walkthrough-location map from pokeyellow, join the hidden-item /
coin markers, and emit the manifest + QA overlays the Rails app consumes.

Usage:
  python tools/maps/build_manifest.py --pokeyellow ~/Code/pokeyellow [--force]

Outputs (paths relative to the porynet_web repo root):
  app/assets/images/walkthrough/yellow/maps/<name>.png   colored map (gitignored -> R2)
  app/models/walkthrough/yellow_maps.json                manifest (committed)
  tools/maps/qa/<name>.png                               marker-overlay preview (gitignored)
  tools/maps/REPORT.md                                   counts + anything to review
"""
import argparse
import json
import pathlib
from PIL import Image, ImageDraw

import render_maps
import parse_hidden

REPO = pathlib.Path(__file__).resolve().parents[2]
IMG_DIR = REPO / "app/assets/images/walkthrough/yellow/maps"
QA_DIR = pathlib.Path(__file__).resolve().parent / "qa"
MANIFEST = REPO / "app/models/walkthrough/yellow_maps.json"
REPORT = pathlib.Path(__file__).resolve().parent / "REPORT.md"
R2_PREFIX = "walkthrough/yellow/maps"

# slug -> ordered [(map_label, floor_label, parent_map_const_or_None)]
# parent is only needed for interiors that aren't cavern/cemetery (they inherit a town palette).
_SIMPLE = {  # single overworld map, no parent
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
_GYM_CITIES = {  # town map + gym interior (gym inherits the city palette)
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


# extra interior maps appended to a location (label, floor, parent_map_const)
_INTERIORS = {
    "pallet-town": [("RedsHouse2F", "Your room", "PALLET_TOWN")],
}

# hand-placed points of interest that aren't hidden-item events (grid coords, 16px cells)
_ANNOTATIONS = {
    "RedsHouse2F": [{"grid": [0, 0], "kind": "poi", "label": "PC · free Potion"}],
}


def location_maps():
    out = {}
    for slug, label in _SIMPLE.items():
        out[slug] = [(label, "", None)]
    for slug, (town, gym, parent) in _GYM_CITIES.items():
        out[slug] = [(town, "", None), (gym, "Gym", parent)]
    out.update(_DUNGEONS)
    for slug, extras in _INTERIORS.items():
        out[slug] = out.get(slug, []) + extras
    return out


def image_name(slug, floor):
    return slug if not floor else f"{slug}-{floor.lower().replace(' ', '-')}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pokeyellow", required=True)
    ap.add_argument("--force", action="store_true", help="re-render PNGs that already exist")
    args = ap.parse_args()
    root = str(pathlib.Path(args.pokeyellow).expanduser())

    headers = render_maps.parse_headers(pathlib.Path(root))  # label -> (const, tileset)
    markers = parse_hidden.markers_by_map(root)              # const -> [markers]
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    QA_DIR.mkdir(parents=True, exist_ok=True)

    manifest, missing, fallbacks, marker_total = {}, [], [], 0
    for slug, maps in sorted(location_maps().items()):
        entries = []
        for label, floor, parent in maps:
            if label not in headers:
                missing.append(f"{slug}: {label}")
                continue
            const, tileset = headers[label]
            img = render_maps.render_map(root, label, parent)
            name = image_name(slug, floor)
            png = IMG_DIR / f"{name}.png"
            if args.force or not png.exists():
                img.save(png)
            mk = []
            for m in markers.get(const, []):
                mk.append({"x_pct": round(m["px"][0] / img.width, 5),
                           "y_pct": round(m["px"][1] / img.height, 5),
                           "kind": m["kind"], "label": m["label"]})
            for a in _ANNOTATIONS.get(label, []):
                gx, gy = a["grid"]
                unit = parse_hidden.UNIT_PX
                mk.append({"x_pct": round((gx * unit + unit // 2) / img.width, 5),
                           "y_pct": round((gy * unit + unit // 2) / img.height, 5),
                           "kind": a["kind"], "label": a["label"]})
            marker_total += len(mk)
            entries.append({"image": f"{R2_PREFIX}/{name}.png", "width": img.width,
                            "height": img.height, "floor": floor, "markers": mk})
            _write_qa(img, mk, QA_DIR / f"{name}.png")
        if entries:
            manifest[slug] = entries

    MANIFEST.write_text(json.dumps({"source": "pret/pokeyellow", "locations": manifest}, indent=2))
    _write_report(manifest, missing, marker_total)
    print(f"locations: {len(manifest)}  maps: {sum(len(v) for v in manifest.values())}  "
          f"markers: {marker_total}  missing: {len(missing)}")
    if missing:
        print("MISSING labels:", ", ".join(missing))


def _write_qa(img, markers, path):
    qa = img.convert("RGB").copy()
    d = ImageDraw.Draw(qa)
    for m in markers:
        x, y = m["x_pct"] * img.width, m["y_pct"] * img.height
        color = (255, 40, 90) if m["kind"] == "item" else (255, 194, 61)
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=color, outline=(0, 0, 0))
        d.text((x + 6, y - 6), m["label"], fill=(0, 0, 0))
    qa.save(path)


def _write_report(manifest, missing, marker_total):
    lines = ["# Map generation report", "",
             f"- locations: **{len(manifest)}**",
             f"- maps rendered: **{sum(len(v) for v in manifest.values())}**",
             f"- markers placed: **{marker_total}**",
             f"- missing map labels: **{len(missing)}**", ""]
    if missing:
        lines += ["## Missing labels (no pokeyellow header found)", ""] + [f"- {m}" for m in missing] + [""]
    lines += ["## Locations", ""]
    for slug, entries in sorted(manifest.items()):
        floors = ", ".join(f"{e['floor'] or 'main'}({len(e['markers'])})" for e in entries)
        lines.append(f"- `{slug}`: {floors}")
    REPORT.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
