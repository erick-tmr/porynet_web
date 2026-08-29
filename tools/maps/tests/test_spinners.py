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
from spinners import arrow_tiles, route

MANIFEST = json.loads(
    (pathlib.Path(__file__).resolve().parents[3]
     / "app/models/walkthrough/yellow_maps.json").read_text())

# The floors that ship a drawn line. Viridian Gym is an arrow floor too, but its ROUTES entry is
# a single doorway, so it has no walk to draw yet; see the gate test at the bottom.
DRAWN = ("RocketHideoutB2F", "RocketHideoutB3F")
# Every floor that ships a line, arrow-driven or walked. The walkability promise is the same for
# both; only the ball-collecting one is particular to the mazes, whose stops are the balls.
LINED = (*DRAWN, "FuchsiaGym")


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


@pytest.mark.parametrize("label", LINED)
def test_a_route_only_ever_crosses_cells_the_game_lets_you_cross(root, label):
    """The promise the drawn line makes. Every cell of it is either one you can stand on or an
    arrow tile you are carried over, and every step of it is one cell in one direction, so the
    line cannot cut a corner through a crate or teleport across a wall."""
    stops = spinners.route_stops(root, label)
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


def test_only_a_floor_with_a_written_walk_gets_a_line(root):
    """Three gates, and each matters. Outside, the flood that orders the pins walks up ledges you
    can only fall down, so a line drawn from it would trace a way across the field that does not
    exist. Viridian Gym is an arrow floor whose route is a single doorway, which says nothing about
    the way round: it gets a line the day its ROUTES entry names one. And a floor with no arrows
    gets one only by being named in WALKED, which is a judgement about whether the walls are
    visible, not something to infer."""
    assert spinners.drawn_route(root, "Route3") == [], "no arrows, however long its ROUTES entry"
    assert len(paths.ROUTES["ViridianGym"]) == 1
    assert spinners.drawn_route(root, "ViridianGym") == [], "arrows, but no walk written down yet"
    assert spinners.drawn_route(root, "RocketHideoutB2F"), "both, so it gets one"
    assert spinners.drawn_route(root, "CeruleanGym") == [], "no arrows and not named in WALKED"
    assert spinners.drawn_route(root, "FuchsiaGym"), "no arrows, but its walls are invisible"


def test_the_fuchsia_line_runs_from_the_door_to_koga(root):
    """The one floor whose line is a plain walk. Its stops are its own rather than its ROUTES
    entry, because the walk ends on the leader and the pins have to letter him last however early
    the door reaches him: naming him a waypoint would deal T5 to Koga and push two Jugglers and a
    Tamer behind him.

    The corners it turns are named too, because the shortest way is not the walkable one: left to
    itself the solver climbs the middle lane and stands on the two trainers in it, which is a cell
    the game never lets you occupy. The line goes round them instead, and ends up passing four of
    the six rather than treading on two."""
    door, koga = (4, 17), (4, 10)
    legs = spinners.route(root, "FuchsiaGym", spinners.route_stops(root, "FuchsiaGym"))
    cells = [cell for leg in legs for cell in leg]
    people = {(8, 13): "T1", (8, 2): "T4", (2, 7): "T5", (3, 5): "T6"}

    assert cells[0] == door
    assert cells[-1] == koga
    assert [cell for cell in people if cell in cells] == [], "it stands on nobody but the leader"
    assert all(any((x + dx, y + dy) in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
               for x, y in people), "but it passes within a tile of all four"
    assert paths.ROUTES["FuchsiaGym"] == ("exit-4-17",), "the lettering waypoints stay as they were"


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


@pytest.mark.parametrize(("label", "rides", "in_maze"), [
    ("RocketHideoutB2F", [3, 5, 6, 7], [3, 4, 5, 6, 7]),
    ("RocketHideoutB3F", [4, 5, 7], [4, 5, 7]),
])
def test_which_legs_go_into_the_maze(root, label, rides, in_maze):
    """Which steps get a map of their own in the guide (the `line:` entries in yellow.rb).

    Not "rides an arrow", which is the narrower question: B2F's walk from the Moon Stone to the
    Nugget threads between the arrows without stepping on one, and following the north wall out of
    a maze you were thrown into is exactly as hard to read off prose as the ride in was. So the
    test is whether a leg goes into the patch of floor the arrows occupy at all. The rest are
    plain corridor walks, in at the door and round to the stairs, and a picture of a corridor is a
    picture of nothing."""
    tiles = set(arrow_tiles(root, label))
    xs, ys = zip(*tiles, strict=True)
    legs = route(root, label, paths.route_cells(root, label))

    def in_the_maze(cells):
        return any(min(xs) <= x <= max(xs) and min(ys) <= y <= max(ys) for x, y in cells)

    assert [n for n, cells in enumerate(legs, 1) if any(c in tiles for c in cells)] == rides
    assert [n for n, cells in enumerate(legs, 1) if in_the_maze(cells)] == in_maze


def test_the_warp_gym_hops_pad_to_pad_and_treads_on_neither(root):
    """Saffron's gym is nine sealed rooms, so its line is nine of them: land on a pad, cross the
    room, leave by another. Every leg has to start and end on a pad and touch no other, because a
    line over a spare pad is an instruction to stand where the game throws you somewhere else, and
    it has to keep off the people, who are solid. The one exception is the end of the walk, which
    is a gym leader: the line runs to Sabrina because there is nothing after her."""
    pads = set(paths.warp_pads(root, "SaffronGym"))
    people = {obj["grid"] for obj in
              sources.parse_object_events(root, "SaffronGym", include_battlers=True)}
    legs = spinners.warped_route(root, "SaffronGym")

    assert len(legs) == 9, "the entrance, seven trainers' rooms, and Sabrina's"
    assert [leg[0] for leg in legs][1:] == [tuple(run[0]) for run in spinners.WARPED["SaffronGym"]][1:]
    assert all(leg[-1] in pads for leg in legs[:-1]), "each hop finishes on the pad it leaves by"
    assert legs[-1][-1] == (9, 8), "and the last finishes on Sabrina"
    assert [cell for leg in legs for cell in leg[1:-1] if cell in pads] == []
    assert [cell for leg in legs for cell in leg[1:-1] if cell in people] == []
    assert all(abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1
               for leg in legs for a, b in zip(leg, leg[1:], strict=False)), "every step is a step"


def test_a_warp_gyms_rooms_are_reached_in_the_order_its_pads_join_them(root):
    """The nine hops are not nine guesses: each one's pad really lands on the next one's start, so
    following the line room by room is following the game. Only the northwest room's pad reaches
    Sabrina, which is what fixes the order the rest are taken in."""
    pads = paths.warp_pads(root, "SaffronGym")
    legs = spinners.warped_route(root, "SaffronGym")

    assert [pads[leg[-1]] for leg in legs[:-1]] == [leg[0] for leg in legs[1:]]
    assert pads[legs[-2][-1]] == legs[-1][0] == (11, 11), "the one pad into her room"


def test_the_warp_gyms_letters_and_its_line_take_the_rooms_in_one_order(root):
    """Two answers to one question live apart: `paths.ROUTES` letters the pins and `WARPED` draws
    the line. A reader following the arrows meets T1 first and T8 last, so if the two ever
    disagreed the map would be arguing with itself. Both are really the room order, so they are
    compared as rooms rather than as cells: which pad a run leaves by is the line's business."""
    def room(cell):
        x, y = cell
        return (0 if x <= 5 else 1 if x <= 12 else 2, 0 if y <= 5 else 1 if y <= 11 else 2)

    lettered = [room(cell) for cell in
                paths.marker_cells(root, "SaffronGym", paths.ROUTES["SaffronGym"])]
    drawn = [room(run[0]) for run in spinners.WARPED["SaffronGym"]]

    assert lettered == drawn, "the order the pins are lettered in is the order the line is drawn in"
