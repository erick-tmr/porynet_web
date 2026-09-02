"""The drawn boulder pushes, against the floors they are pushed across.

The corners are written down rather than solved, so what these hold is that every one of them is a
move the game allows and that the line ends where the step says it does. A push that fails either
is a picture of something nobody can do, drawn beside prose telling them to do it."""
import pytest

import boulders
import sources


def test_a_push_is_expanded_a_cell_at_a_time():
    """Corners in, cells out: the drawn line turns where the boulder turns, and a leg of one shove
    is two cells rather than a point."""
    assert boulders.cells((18, 10), ((17, 10), (17, 6))) == [
        (18, 10), (17, 10), (17, 9), (17, 8), (17, 7), (17, 6)]
    assert boulders.cells((17, 6), ((18, 6),)) == [(17, 6), (18, 6)]


@pytest.mark.parametrize("label", sorted(boulders.PUSHES))
def test_every_push_is_one_the_game_allows(root, label):
    """The whole of `check` on every floor that draws one: each leg starts on a boulder the map
    declares, every cell it crosses is dry ground, and every shove is made from behind."""
    boulders.check(root, label)


def test_a_boulder_shipped_hidden_still_counts_as_placed(root):
    """Every boulder below 1F is toggled on when the one above it falls, so the floor being pushed
    across declares it and does not display it. Reading the loaded map rather than the file would
    leave three of the four floors unable to draw anything."""
    loaded = {o["grid"] for o in sources.parse_object_events(root, "SeafoamIslandsB1F")}
    declared = {o["grid"] for o in sources._object_events(root, "SeafoamIslandsB1F")
                if o["sprite_const"] == "SPRITE_BOULDER"}

    assert declared == {(17, 6), (22, 6)}
    assert not declared & loaded, "neither is on the map when you first drop onto the floor"


def test_a_boulder_pushed_into_a_wall_is_refused(root, monkeypatch):
    """B1F's chamber wall is two cells past its first boulder, so a leg written one shove too long
    stops the boulder inside the rock."""
    monkeypatch.setitem(boulders.PUSHES, "SeafoamIslandsB1F", (((17, 6), ((20, 6),)),))

    with pytest.raises(ValueError, match=r"cannot rest on \(20, 6\)"):
        boulders.check(root, "SeafoamIslandsB1F")


def test_a_shove_with_nowhere_to_stand_is_refused(root, monkeypatch):
    """B3F's leftmost boulder has open floor to its west and the chamber wall to its east, so the
    move is one the map allows and the shove is not: there is nowhere to put the hero."""
    monkeypatch.setitem(boulders.PUSHES, "SeafoamIslandsB3F", (((3, 15), ((2, 15),)),))

    with pytest.raises(ValueError, match=r"nobody can stand on \(4, 15\)"):
        boulders.check(root, "SeafoamIslandsB3F")


def test_a_boulder_shoved_over_a_plateau_edge_is_refused(root, monkeypatch):
    """Victory Road 3F's plateau is walkable rock a step above the lane its boulder is pushed
    along, and nothing in the collision map says so: both sides are open floor. What says so is the
    tileset's own pair table, which is why a line drawn over collision alone would happily shove
    this boulder off the lane and onto the plateau halfway across the floor."""
    monkeypatch.setitem(boulders.PUSHES, "VictoryRoad3F",
                        (((22, 3), ((22, 1), (12, 1), (12, 2))),))

    with pytest.raises(ValueError, match=r"\(12, 1\) cannot be shoved to \(12, 2\)"):
        boulders.check(root, "VictoryRoad3F")


def test_a_boulder_will_not_go_up_the_steps(root, monkeypatch):
    """The other rule the routine names outright, and the other one collision alone passes: a
    flight of cave steps is a tile you can stand on, so the two cells either side of Victory Road
    2F's south stair read as a legal shove and are not."""
    monkeypatch.setitem(boulders.PUSHES, "VictoryRoad2F",
                        (((23, 16), ((21, 16), (21, 15))),))

    with pytest.raises(ValueError, match=r"will not go up the steps at \(21, 15\)"):
        boulders.check(root, "VictoryRoad2F")


def test_victory_road_1f_draws_the_same_boulder_shoved_two_ways(root):
    """The one place a floor draws one boulder twice. 1F's top corridor holds two balls and one
    boulder, and whichever way it is shoved it seals the ball it is not clearing, so the two legs
    are alternatives rather than a journey: same starting cell, four shoves each, ending a cell
    apart. Leaving the floor and coming back is what lets you have both."""
    first, second = boulders.PUSHES["VictoryRoad1F"][1:]

    assert first[0] == second[0] == (14, 2)
    assert boulders.cells(*first)[-1] == (11, 1), "north into the spur, freeing the Rare Candy"
    assert boulders.cells(*second)[-1] == (10, 2), "one further west, freeing the TM"


def test_a_leg_that_starts_nowhere_near_a_boulder_is_refused(root, monkeypatch):
    monkeypatch.setitem(boulders.PUSHES, "SeafoamIslandsB1F", (((16, 6), ((17, 6),)),))

    with pytest.raises(ValueError, match="no boulder stands on"):
        boulders.check(root, "SeafoamIslandsB1F")


def test_a_push_off_a_boulder_nothing_drops_is_refused(root, monkeypatch):
    """B1F declares two boulders and shows neither, so a leg starting on one is only honest if a
    hole above really drops a boulder there. The map file cannot say: it declares them either way,
    which is what makes this worth checking rather than assuming."""
    monkeypatch.setattr(boulders.holes, "by_map", lambda _root: {})

    with pytest.raises(ValueError, match=r"nothing drops a boulder onto \(17, 6\)"):
        boulders.check(root, "SeafoamIslandsB1F")


def test_every_push_starts_on_a_boulder_a_hole_above_really_drops(root):
    """The join between the two halves: `holes.dropped_boulders` says where each drop lands, and
    every leg that starts on a boulder the floor does not show has to start on one of them.
    Seafoam 1F's east hole is the reason it is not obvious, dropping its boulder two cells west of
    itself, on the cell B1F's second push starts from."""
    starts = {label: [tuple(start) for start, _corners in pushes]
              for label, pushes in boulders.PUSHES.items()}
    dropped = {cell for label in ["SeafoamIslands1F", "SeafoamIslandsB1F", "SeafoamIslandsB2F"]
               for _dest, cell in boulders.holes.dropped_boulders(root, label)}

    assert starts["SeafoamIslandsB1F"] == [(17, 6), (22, 6)]
    assert set(starts["SeafoamIslandsB1F"]) <= dropped
    assert set(starts["SeafoamIslandsB2F"]) <= dropped
    assert not set(starts["SeafoamIslands1F"]) & dropped, "1F's own two are there from the start"


def test_the_pushes_that_should_drop_a_boulder_end_over_a_hole(root):
    """Six of Seafoam's eight legs end on a hole. The two that do not are the shoves that park a
    boulder out of the way: the second-from-left on B3F, moved west so the leftmost can be reached,
    and the right of the pair, pushed up into the corner.

    Victory Road is the other way round, and one leg in seven ends on a hole. Its boulders are
    shoved onto floor switches that lift a barrier somewhere else on the floor, or across a corridor
    to seal a ball; only 3F's last one is dropped through, and that is a shortcut down to 2F rather
    than the way a floor is opened."""
    ending = {label: [boulders.ends_in_a_hole(root, label, boulders.cells(*push))
                      for push in pushes]
              for label, pushes in boulders.PUSHES.items()}

    assert ending == {
        "SeafoamIslands1F": [True, True],
        "SeafoamIslandsB1F": [True, True],
        "SeafoamIslandsB2F": [True, True],
        "SeafoamIslandsB3F": [False, True, False, True],
        "VictoryRoad1F": [False, False, False],
        "VictoryRoad2F": [False, False],
        "VictoryRoad3F": [False, True]}


def test_a_floor_with_no_boulders_draws_no_line(root):
    assert boulders.drawn_pushes(root, "ViridianForest") == []


def test_a_leg_is_drawn_in_the_pixels_the_app_hangs_its_svg_in(root):
    """Cell centres, the same measure `spinners.drawn_route` hands over, so one SVG serves both.

    All but the first, which starts at the near edge of the boulder's own cell so the line does not
    bury the boulder: (17, 6) centres on 280 and the line starts eight pixels along, at the join
    with the hole it is being shoved into."""
    assert boulders.drawn_pushes(root, "SeafoamIslandsB1F")[0] == [[288, 104], [296, 104]]
    assert boulders.drawn_pushes(root, "SeafoamIslands1F")[0] == [
        [288, 168], [280, 168], [280, 152], [280, 136], [280, 120], [280, 104]]
