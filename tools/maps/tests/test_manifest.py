"""Per-map regression tests that pin the generated manifest to the game data.

Two guards run for every location map:

- `test_map_markers_match_the_committed_manifest` rebuilds a map's markers straight from
  pokeyellow and asserts they equal what `yellow_maps.json` holds. This is the golden test: change
  the marker/exit algorithm and it fails for *every* map that moved, not just the one you were
  fixing, so a fix for one map cannot silently shift another. When a change is intentional, rerun
  `python tools/maps/build.py --pokeyellow <path>` and review the manifest diff.

- `test_connection_exit_sits_inside_its_strip` is the correctness invariant behind the Route 22
  fix: a map connection only shares a strip of the shared edge (offset in the header), and the
  exit marker has to sit inside that strip, not merely on some open tile elsewhere on the edge.

These read the real pokeyellow checkout, so they skip when it is absent (see conftest)."""
import json
import pathlib

import pytest

import decks
import locations
import markers
import sources

MANIFEST = json.loads(
    (pathlib.Path(__file__).resolve().parents[3]
     / "app/models/walkthrough/yellow_maps.json").read_text())

# name -> the manifest entry, and name -> (asm label, floor) so a test can rebuild it.
MAP_ENTRIES = {m["name"]: m for maps in MANIFEST["locations"].values() for m in maps}


def _registry(root):
    headers = sources.parse_headers(root)
    out = {}
    for slug, maps in locations.location_maps().items():
        for label, floor, _parent in maps:
            if label in headers:
                out[locations.image_name(slug, floor)] = (label, headers[label][0])
    return out


MAP_NAMES = sorted(MAP_ENTRIES)


# Exit keys are settled per location, not per map, because a staircase's two ends share one key.
# So the golden test rebuilds a whole location and then reads back the map it is checking.
def _rebuild_location(root, slug):
    headers = sources.parse_headers(root)
    entries, labels, warps, consts = [], [], {}, {}
    for label, floor, _parent in locations.location_maps()[slug]:
        if label not in headers:
            continue
        name = locations.image_name(slug, floor)
        entry = MAP_ENTRIES[name]
        entries.append({"name": name, "markers": decks.area_markers(
            root, label, floor, entry["width"], entry["height"])})
        labels.append(label)
        warps[label] = sources.parse_warp_events(root, label)
        consts[label] = headers[label][0]
    markers.link_exit_keys(entries, labels, warps, consts)
    return {e["name"]: e["markers"] for e in entries}


MAP_SLUGS = {locations.image_name(slug, floor): slug
             for slug, maps in locations.location_maps().items()
             for _label, floor, _parent in maps}


@pytest.mark.parametrize("name", MAP_NAMES)
def test_map_markers_match_the_committed_manifest(root, name):
    built = _rebuild_location(root, MAP_SLUGS[name])[name]

    assert built == MAP_ENTRIES[name]["markers"], (
        f"{name}: generator output drifted from the committed manifest; "
        f"rerun tools/maps/build.py and review the diff")


@pytest.mark.parametrize("name", MAP_NAMES)
def test_connection_exit_sits_inside_its_strip(root, name):
    label, _const = _registry(root)[name]
    entry = MAP_ENTRIES[name]
    w_cells, h_cells = entry["width"] // sources.UNIT_PX, entry["height"] // sources.UNIT_PX
    dims, _num_city, _first_indoor = sources.parse_map_constants(root)
    exits = {m["id"]: m for m in entry["markers"] if m["cat"] == "exit"}

    for direction, dest, offset in sources.parse_connections(root, label):
        marker = exits.get(f"exit-{direction}")
        assert marker, f"{name}: no exit for its {direction} connection to {dest}"
        strip = markers.connection_span(
            markers.edge_cells(direction, w_cells, h_cells),
            direction, offset, dims.get(dest), w_cells, h_cells)
        assert tuple(marker["grid"]) in strip, (
            f"{name}: {direction} exit at {marker['grid']} is outside the "
            f"strip it shares with {dest}")
