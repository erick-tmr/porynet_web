"""The dungeon warps: what counts as a hole, and which tile each one drops you on.

Every case here is a decision the parser has to get right rather than a number it happens to
read, because the two tables that describe a hole live nowhere near the floor it is cut into and
nothing in the map file mentions it at all."""
import pytest

import holes
import markers
import sources


@pytest.fixture(autouse=True)
def _fresh_caches():
    """The parsers memoize per map, so a test that fakes a script would otherwise leave its answer
    cached for the ones after it."""
    yield
    holes.hole_cells.cache_clear()
    holes._script.cache_clear()
    holes.by_map.cache_clear()


def test_a_floors_holes_are_read_in_the_order_the_game_numbers_them(root):
    """The position in this list is a hole's whole identity in DungeonWarpList, so the order is
    load-bearing: read it backwards and every landing pairs with the wrong gap."""
    assert holes.hole_cells(root, "SeafoamIslands1F") == ((17, 6), (24, 6))
    assert holes.hole_cells(root, "SeafoamIslandsB3F") == ((3, 16), (6, 16))
    assert holes.hole_cells(root, "ViridianForest") == (), "a floor with no dungeon warps has none"


def test_the_mansions_inlined_check_is_found_like_the_shared_one(root):
    """Pokemon Mansion 3F does not call IsPlayerOnDungeonWarp: it keeps its own copy under a local
    label. Matching the routine by name alone would leave the mansion holeless."""
    assert holes.hole_cells(root, "PokemonMansion3F") == ((16, 14), (17, 14), (19, 14))


def test_the_two_tables_pair_row_for_row(root):
    """DungeonWarpList and DungeonWarpData are parallel, so a landing is looked up by (destination,
    position) rather than searched for."""
    landings = holes.landings(root)

    assert landings[("SEAFOAM_ISLANDS_B1F", 1)] == (18, 7)
    assert landings[("SEAFOAM_ISLANDS_B4F", 2)] == (5, 14)
    assert landings[("VICTORY_ROAD_2F", 2)] == (22, 16)


def test_victory_roads_switch_is_not_a_hole(root):
    """Its coord list holds the boulder switch at position one and the hole at position two. Only
    the second has a DungeonWarpList row, which is what tells them apart: stand on the switch and
    nothing opens under you."""
    assert holes.hole_cells(root, "VictoryRoad3F") == ((3, 5), (23, 15))

    drops = holes.floor_holes(root, "VictoryRoad3F")

    assert [group["cells"] for group in drops] == [[(23, 15)]]
    assert drops[0]["landing"] == (22, 16)


def test_adjacent_cells_over_one_landing_are_one_hole(root):
    """The mansion's first two cells are a two-tile gap in the floor, not two holes, and the game
    says so by dropping both on the same tile. Left apart they draw two pins a tile from each
    other and give one gap two letters."""
    drops = holes.floor_holes(root, "PokemonMansion3F")

    assert [group["cells"] for group in drops] == [[(16, 14), (17, 14)], [(19, 14)]]
    assert drops[0]["center"] == (16.5, 14.0), "the pin sits between the two tiles"
    assert drops[0]["anchor"] == (16, 14), "and its id anchors to the min cell"
    assert [group["dest"] for group in drops] == ["POKEMON_MANSION_1F", "POKEMON_MANSION_2F"]


def test_a_destination_is_only_taken_when_the_floors_own_script_names_it(root):
    """Six floors share slot 1, so the row is picked by the destination the script sets. The word
    boundary matters: SEAFOAM_ISLANDS_B1F sits inside the TOGGLE_..._BOULDER_1 constant a few
    lines above the one that counts."""
    assert holes._destination(root, "SeafoamIslands1F", 1) == ("SEAFOAM_ISLANDS_B1F", (18, 7))
    assert holes._destination(root, "VictoryRoad3F", 1) is None


def test_an_ambiguous_slot_is_an_error_rather_than_a_guess(root, monkeypatch):
    monkeypatch.setattr(holes, "landings", lambda _root: {
        ("SEAFOAM_ISLANDS_B1F", 1): (18, 7), ("SEAFOAM_ISLANDS_B2F", 1): (19, 7)})
    monkeypatch.setattr(holes, "_script", lambda _root, _label:
                        "ld a, SEAFOAM_ISLANDS_B1F\nld a, SEAFOAM_ISLANDS_B2F\n")

    with pytest.raises(ValueError, match="names 2 destinations"):
        holes._destination(root, "SeafoamIslands1F", 1)


def test_a_floor_whose_named_label_holds_no_coords_has_no_holes(root, monkeypatch):
    """The check is found by the label handed to it, so a script that names one and defines it
    somewhere the parser cannot see reports nothing rather than crashing."""
    monkeypatch.setattr(holes, "_script", lambda _root, _label:
                        "\tld hl, .holeCoords\n\tcall IsPlayerOnDungeonWarp\n")

    assert holes.hole_cells(root, "SeafoamIslands1F") == ()


def test_only_the_floors_with_holes_are_listed(root):
    """Six floors in the whole game, and every one of them is a boulder or a maze puzzle."""
    assert sorted(holes.by_map(root)) == [
        "PokemonMansion3F", "SeafoamIslands1F", "SeafoamIslandsB1F", "SeafoamIslandsB2F",
        "SeafoamIslandsB3F", "VictoryRoad3F"]


def test_a_floor_draws_its_own_gaps_and_nothing_it_is_dropped_onto(root):
    """Only the hole itself. Its far end is the awkward half: the game lands the player one way off
    it and the boulder another, so a pin down there points at neither. Seafoam B1F is the floor
    that would carry both, and draws the two gaps it holds."""
    const = sources.parse_headers(root)["SeafoamIslandsB1F"][0]
    drawn = [m for m in markers.build_markers(root, "SeafoamIslandsB1F", const, 480, 288)
             if m["cat"] == "hole"]

    assert {tuple(m["grid"]): (m["key"], m["name"], m["glyph"]) for m in drawn} == {
        (18, 6): ("D1", "B2F", "▼"), (23, 6): ("D2", "B2F", "▼")}, \
        "each names the floor it drops to, trimmed like a staircase, and only goes one way"


def test_a_floors_holes_number_from_one_like_every_other_category(root):
    """No pairing across floors any more, so a hole is numbered where it is cut, in map order."""
    keyed = {}
    for label, const in [("SeafoamIslands1F", "SEAFOAM_ISLANDS_1F"),
                         ("SeafoamIslandsB1F", "SEAFOAM_ISLANDS_B1F")]:
        keyed[label] = {m["id"]: m["key"] for m
                        in markers.build_markers(root, label, const, 480, 288)
                        if m["cat"] == "hole"}

    assert keyed["SeafoamIslands1F"] == {"hole-17-6": "D1", "hole-24-6": "D2"}
    assert keyed["SeafoamIslandsB1F"] == {"hole-18-6": "D1", "hole-23-6": "D2"}
