"""The arrow-tile mazes: read out of the game, solved, and drawn.

The invariant that matters is the last one here. A drawn route is a promise that if you follow the
line you collect the floor and reach the way out, so every cell of it has to be one the game
really lets you cross, and every step of it has to be a step. A solver bug shows up as a line
sailing through a crate, which is exactly the kind of thing that reads as fine in a screenshot.
"""
import json
import pathlib

import pytest

import markers
import paths
import sources
import spinners

MANIFEST = json.loads(
    (pathlib.Path(__file__).resolve().parents[3]
     / "app/models/walkthrough/yellow_maps.json").read_text())

# The floors that ship a drawn line. Viridian Gym is an arrow floor too, but its ROUTES entry is
# a single doorway, so it has no walk to draw yet; see the gate test at the bottom.
DRAWN = ("RocketHideoutB2F", "RocketHideoutB3F")


def test_the_arrow_table_is_read_x_first(root):
    """`map_coord_movement` takes x, y and `dbmapcoord` swaps the pair on the way into the ROM, so
    the bytes come out y then x. Reading the source in ROM order transposes the whole maze onto
    cells that are mostly wall, which is how this was caught: B2F's first entry landed on (9,4),
    three rows above the floor's own top wall."""
    tiles = spinners.arrow_tiles(root, "RocketHideoutB2F")

    assert tiles[(4, 9)] == (("LEFT", 2),), "the first entry, map_coord_movement 4, 9"
    assert (9, 4) not in tiles, "which is not the transposed cell up in the wall"


def test_a_floor_with_no_arrows_has_no_table(root):
    assert spinners.arrow_tiles(root, "RocketHideoutB1F") == {}
    assert spinners.arrow_tiles(root, "NoSuchMap") == {}, "a map with no script at all"


def test_a_push_list_plays_out_one_cell_at_a_time(root):
    """The run is drawn, not just its endpoints, so a line along it turns where the hero turns."""
    assert spinners.push_path((10, 10), (("UP", 1), ("LEFT", 3))) == [
        (10, 10), (10, 9), (9, 9), (8, 9), (7, 9)]


def test_a_ride_chains_through_every_arrow_it_lands_on(root):
    """The script re-arms when a run ends, so an arrow that drops you on another arrow is one
    ride. B2F's (8,12) is a single push up, and it lands you clear, but (12,13) climbs four and
    then runs the length of the floor because the tile it stops on takes over."""
    assert spinners.slide_from(root, "RocketHideoutB2F", (8, 12)) == [(8, 12), (8, 11)]

    long_ride = spinners.slide_from(root, "RocketHideoutB2F", (12, 13))

    assert long_ride[-1] == (2, 9)
    assert len(long_ride) == 15, "four up, then ten left off the tile it lands on"


def test_a_ride_that_never_lets_go_is_an_error(root, monkeypatch):
    """A parse that read a tile as pushing onto itself would otherwise spin forever."""
    monkeypatch.setattr(spinners, "arrow_tiles", lambda *_: {(1, 1): (("LEFT", 0),)})

    with pytest.raises(ValueError, match="never let go"):
        spinners.slide_from(root, "RocketHideoutB2F", (1, 1))


def test_a_trip_with_no_way_through_is_an_error(root):
    """Better a failed build than a line drawn between two places you cannot get between."""
    with pytest.raises(ValueError, match="no way from"):
        spinners.leg(root, "RocketHideoutB2F", (21, 8), (0, 0))


def test_a_trip_to_where_you_already_are_is_one_cell(root):
    assert spinners.leg(root, "RocketHideoutB2F", (21, 8), (21, 8)) == [(21, 8)]


def test_the_solver_rides_the_arrows_rather_than_walking_round_them(root):
    """The Moon Stone sits in the far northwest corner behind the whole maze. On foot from the
    B3F stairs there is no way to it at all; the only way is to step onto the lower of the two
    leftward arrows and be thrown the length of the floor, which is what the line has to show."""
    cells = spinners.leg(root, "RocketHideoutB2F", (21, 8), (1, 11))

    assert cells[0] == (21, 8) and cells[-1] == (1, 11)
    assert (17, 11) in cells, "the arrow it enters the maze on"
    assert (2, 9) in cells, "the stop tile that ride ends on, most of the way across the floor"


@pytest.mark.parametrize("label", DRAWN)
def test_a_route_only_ever_crosses_cells_the_game_lets_you_cross(root, label):
    """The promise the drawn line makes. Every cell of it is either one you can stand on or an
    arrow tile you are carried over, and every step of it is one cell in one direction, so the
    line cannot cut a corner through a crate or teleport across a wall."""
    stops = paths.route_cells(root, label)
    const, tileset = sources.parse_headers(root)[label]
    _index, width_blocks, _height = sources.parse_map_constants(root)[0][const]

    for cells in spinners.route(root, label, stops):
        for cell in cells:
            assert markers.cell_is_walkable(root, label, tileset, width_blocks, cell), \
                f"{label}: the route crosses {cell}, which the game walls off"
        for here, there in zip(cells, cells[1:], strict=False):
            assert abs(here[0] - there[0]) + abs(here[1] - there[1]) == 1, \
                f"{label}: the route jumps from {here} to {there}"


@pytest.mark.parametrize("label", DRAWN)
def test_a_route_collects_every_ball_on_its_floor(root, label):
    """What the line is for: follow it and the floor is cleared. A ball left off the route is a
    ball a reader walks past, so the stops have to name all of them."""
    balls = {tuple(o["grid"]) for o in sources.parse_object_events(root, label)
             if o["kind"] == "item"}
    drawn = {cell for cells in spinners.route(root, label, paths.route_cells(root, label))
             for cell in cells}

    assert balls <= drawn, f"{label}: the route misses {sorted(balls - drawn)}"


def test_only_an_arrow_floor_with_a_written_walk_gets_a_line(root):
    """Two gates, and both matter. Outside, the flood that orders the pins walks up ledges you can
    only fall down, so a line drawn from it would trace a way across the field that does not
    exist. And Viridian Gym is an arrow floor whose route is a single doorway, which says nothing
    about the way round: it gets a line the day its ROUTES entry names one."""
    assert spinners.drawn_route(root, "Route3") == [], "no arrows, however long its ROUTES entry"
    assert len(paths.ROUTES["ViridianGym"]) == 1
    assert spinners.drawn_route(root, "ViridianGym") == [], "arrows, but no walk written down yet"
    assert spinners.drawn_route(root, "RocketHideoutB2F"), "both, so it gets one"


def test_the_line_is_handed_over_in_the_pixels_of_the_map_it_is_drawn_on(root):
    """The app hangs an SVG over the image at whatever size the page gives it, so the points are
    pixel centres of their cells and the app never has to know the grid."""
    first = spinners.drawn_route(root, "RocketHideoutB2F")[0][0]

    assert first == [27 * 16 + 8, 8 * 16 + 8], "the B1F staircase, centred in its cell"


@pytest.mark.parametrize("name", ("rocket-hideout-b2f", "rocket-hideout-b3f"))
def test_the_committed_route_matches_a_fresh_solve(root, name):
    """The golden test for the line, next to the one the markers already have: rebuild it from the
    game and it has to equal what shipped. Change the solver or a waypoint and this fails for
    every floor that moved, not just the one you were looking at."""
    entry = next(e for maps in MANIFEST["locations"].values() for e in maps if e["name"] == name)
    label = f"RocketHideout{entry['floor']}"

    assert entry["route"] == spinners.drawn_route(root, label), (
        f"{name}: the drawn route drifted from the game; rerun tools/maps/build.py")
