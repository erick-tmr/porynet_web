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

import pytest
from conftest import root_for

import decks
import games
import locations
import markers
import paths
import sources


@pytest.fixture
def built_as(monkeypatch):
    """Rebuild as the build itself would, for the game under test.

    The walk a floor is lettered along is per game (`paths.ROUTE_OVERLAYS`), and the build sets
    which one is in force. A test that rebuilds a map has to say so too, or it letters one
    game's pins along another game's walk."""
    def use(game):
        monkeypatch.setattr(paths, "GAME", game)
        return root_for(game)
    return use

# Every game that has a committed manifest is held to it. Both games draw the same map set, so
# a case is a (game, map) pair rather than a map name that would collide between them.
MANIFESTS = {slug: json.loads(game.data("maps").read_text())
             for slug, game in games.CATALOGUE.items() if game.data("maps").exists()}

# (game, name) -> the manifest entry for that map in that game.
MAP_ENTRIES = {(slug, m["name"]): m
               for slug, manifest in MANIFESTS.items()
               for maps in manifest["locations"].values() for m in maps}


def _registry(root):
    headers = sources.parse_headers(root)
    out = {}
    for slug, maps in locations.location_maps().items():
        for label, floor, _parent in maps:
            if label in headers:
                out[locations.image_name(slug, floor)] = (label, headers[label][0])
    return out


CASES = sorted(MAP_ENTRIES)


# Exit keys are settled per location, not per map, because a staircase's two ends share one key.
# So the golden test rebuilds a whole location and then reads back the map it is checking.
def _rebuild_location(root, game, slug):
    headers = sources.parse_headers(root)
    entries, labels, warps, consts = [], [], {}, {}
    for label, floor, _parent in locations.location_maps()[slug]:
        if label not in headers:
            continue
        name = locations.image_name(slug, floor)
        entry = MAP_ENTRIES[(game, name)]
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


@pytest.mark.parametrize(("game", "name"), CASES)
def test_map_markers_match_the_committed_manifest(built_as, game, name):
    root = built_as(game)
    built = _rebuild_location(root, game, MAP_SLUGS[name])[name]

    assert built == MAP_ENTRIES[(game, name)]["markers"], (
        f"{game} {name}: generator output drifted from the committed manifest; "
        f"rerun tools/maps/build.py and review the diff")


@pytest.mark.parametrize(("game", "name"), CASES)
def test_connection_exit_sits_inside_its_strip(built_as, game, name):
    root = built_as(game)
    label, _const = _registry(root)[name]
    entry = MAP_ENTRIES[(game, name)]
    w_cells, h_cells = entry["width"] // sources.UNIT_PX, entry["height"] // sources.UNIT_PX
    dims, _num_city, _first_indoor = sources.parse_map_constants(root)
    exits = {m["id"]: m for m in entry["markers"] if m["cat"] == "exit"}

    for direction, dest, offset in sources.parse_connections(root, label):
        marker = exits.get(f"exit-{direction}")
        assert marker, f"{game} {name}: no exit for its {direction} connection to {dest}"
        strip = markers.connection_span(
            markers.edge_cells(direction, w_cells, h_cells),
            direction, offset, dims.get(dest), w_cells, h_cells)
        assert tuple(marker["grid"]) in strip, (
            f"{game} {name}: {direction} exit at {marker['grid']} is outside the "
            f"strip it shares with {dest}")
