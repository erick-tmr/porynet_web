import json
import pathlib
from collections import Counter

import decks
import locations
import markers
import paths
import roster
import sources

MANIFEST = pathlib.Path(__file__).resolve().parents[3] / "app/models/walkthrough/yellow_maps.json"


def pins(root, label, floor, cat="trainer"):
    """The drawn pins of one floor, keyed by letter, straight off the call the build makes."""
    const = sources.parse_headers(root)[label][0]
    _index, blocks_w, blocks_h = sources.parse_map_constants(root)[0][const]
    return {m["key"]: m for m in
            decks.area_markers(root, label, floor, blocks_w * 32, blocks_h * 32)
            if m["cat"] == cat}


def lettered(root, label, floor):
    """[(letter, who it is)] for one floor, in letter order."""
    drawn = pins(root, label, floor)
    return [(key, drawn[key]["ref"]) for key in sorted(drawn, key=lambda k: int(k[1:]))]


def test_lower_route_10_is_lettered_in_the_order_you_meet_them(root):
    """The case that started this: Route 10 south of Rock Tunnel.

    Coming out of the tunnel's south mouth you walk into the Jr. Trainer first, then the two Hikers
    down the west side, and the Pokémaniac last, and the letters now run that way. Read off the map
    file they came out Hiker, Pokémaniac, Hiker, Jr. Trainer, so a reader hunting for whoever was
    in front of them had to scan the whole section."""
    south = [pair for pair in lettered(root, "Route10", "") if pair[0] in {"T3", "T4", "T5", "T6"}]

    assert south == [("T3", "JR_TRAINER_F:8"), ("T4", "HIKER:7"),
                     ("T5", "HIKER:8"), ("T6", "POKEMANIAC:2")]


def test_route_10_splits_at_the_tunnel_so_each_half_walks_from_its_own_mouth(root):
    """One map, two pages, and the halves do not join up in the game: the north half is walked from
    Route 9 and the south from the tunnel's far mouth. The letters run over the map once for both,
    because both pages draw the same map and a pin can only wear one letter, so the north pair take
    T1 and T2 and the four past the tunnel carry on from T3."""
    assert lettered(root, "Route10", "") == [
        ("T1", "JR_TRAINER_F:7"), ("T2", "POKEMANIAC:1"), ("T3", "JR_TRAINER_F:8"),
        ("T4", "HIKER:7"), ("T5", "HIKER:8"), ("T6", "POKEMANIAC:2")]


def test_viridian_forest_matches_the_order_the_steps_already_walk(root):
    """The forest's steps name their trainers by pin, so the walk has an authored answer to check
    against: the Lass by the gate is T1, the two Bug Catchers up the east side T2 and T3, the one
    across the top T4, and the one holding the west lane T5."""
    drawn = pins(root, "ViridianForest", "")

    assert [tuple(drawn[key]["grid"]) for key in ("T1", "T2", "T3", "T4", "T5")] == [
        (2, 41), (30, 33), (30, 19), (13, 17), (2, 18)]


def test_viridian_forest_letters_its_items_and_hidden_items_along_the_same_walk(root):
    """Items and hidden items are lettered like the trainers are, each series on its own. In the
    forest that puts the western dead-end's Poké Ball at I1, where the map file had it third, and
    the Antidote by the gate at H1, where the map file had it second."""
    items = pins(root, "ViridianForest", "", cat="item")
    hidden = pins(root, "ViridianForest", "", cat="hidden")

    assert [tuple(items[key]["grid"]) for key in ("I1", "I2", "I3")] == [(1, 31), (25, 11), (12, 29)]
    assert [hidden[key]["name"] for key in ("H1", "H2")] == ["Antidote", "Potion"]


def test_exits_keep_their_own_lettering(root):
    """A staircase wears one letter across the two floors it joins, which is a different question
    from how far along a floor it sits, so the walk leaves the exits alone."""
    const = sources.parse_headers(root)["Route10"][0]
    raw = markers.build_markers(root, "Route10", const, 320, 1152, keyed=False)
    walked = paths.walked_markers(root, "Route10", raw)

    assert [m["id"] for m in walked if m["cat"] == "exit"] == \
        [m["id"] for m in raw if m["cat"] == "exit"]


def test_a_trainer_off_the_road_is_lettered_by_the_way_round(root):
    """Route 11's Gambler stands three cells nearer the Vermilion gate than the Youngster as the
    crow flies, but he is down off the road and the Youngster is on it, so the walk reaches the
    Youngster first and he takes the earlier letter. Straight-line distance would letter them the
    other way about."""
    drawn = pins(root, "Route11", "")
    youngster, gambler = drawn["T1"], drawn["T2"]
    entrance = paths.route_cells(root, "Route11")[0]

    assert (youngster["grid"], gambler["grid"]) == ([13, 5], [10, 14])
    assert abs(gambler["grid"][0] - entrance[0]) < abs(youngster["grid"][0] - entrance[0])
    assert paths.walk_rank(root, "Route11", youngster["grid"]) < \
        paths.walk_rank(root, "Route11", gambler["grid"])


def test_a_route_can_name_its_trainers_when_distance_is_not_the_question(root):
    """Route 3's eight are cleared with the least walking back by taking the Lass on the entrance
    row before the Bug Catcher up the bank, which is not the order the flood arrives at them. A
    waypoint can be any pin the map draws, so the route says so outright."""
    assert [pin["ref"] for _key, pin in sorted(pins(root, "Route3", "").items(),
                                               key=lambda kv: int(kv[0][1:]))] == [
        "LASS:1", "BUG_CATCHER:4", "YOUNGSTER:1", "BUG_CATCHER:5",
        "YOUNGSTER:2", "LASS:2", "BUG_CATCHER:6", "LASS:3"]


def test_a_floor_dropped_into_from_three_ladders_is_lettered_pocket_by_pocket(root):
    """Mt. Moon B2F is visited three times down three different ladders. Each trainer belongs to
    the visit whose ladder is nearest, so the Rocket beside the first drop takes T1, the pair by the
    second follow, and the Super Nerd guarding the fossils is last, where the guide reaches him."""
    assert lettered(root, "MtMoonB2F", "B2F") == [
        ("T1", "ROCKET:2"), ("T2", "ROCKET:3"), ("T3", "ROCKET:1"), ("T4", "SUPER_NERD:2")]


def test_a_gym_ends_on_its_leader(root):
    """Every gym is one room off one door, so the walk always finishes at the back of it and the
    leader wears the last letter rather than whichever one the map file happened to give them."""
    for label, floor, leader in (("PewterGym", "Gym", "BROCK:1"),
                                 ("CeruleanGym", "Gym", "MISTY:1"),
                                 ("SaffronGym", "Gym", "SABRINA:1")):
        assert lettered(root, label, floor)[-1][1] == leader, label


def test_saffron_gym_is_walked_over_its_teleport_pads(root):
    """Its eight rooms are sealed: no two share a wall, and the front door reaches nobody on foot.
    The pads are the only way through, so they count as steps there and nowhere else."""
    door = paths.route_cells(root, "SaffronGym")[0]
    sabrina = pins(root, "SaffronGym", "Gym")["T8"]["grid"]

    assert paths.warp_pads(root, "SaffronGym")
    assert paths.warp_pads(root, "Route3") == {}
    assert paths.walk_rank(root, "SaffronGym", sabrina)[1] < paths.UNREACHED
    assert len(paths.reach(root, "SaffronGym", door)) > 200


def test_a_floor_with_no_authored_route_keeps_the_order_it_was_given(root):
    """Most maps hold nothing that needs sorting: one item ball, or none, reads the same either
    way, so they are left out of the table and their pins stay as the map file listed them."""
    entries = [{"cat": "trainer", "grid": [0, 0]}, {"cat": "trainer", "grid": [9, 9]}]

    assert paths.route_cells(root, "PalletTown") == ()
    assert paths.walked_markers(root, "PalletTown", entries) == entries


def test_each_category_is_walked_within_the_slots_it_already_held(root):
    """Numbering runs per category, so an item ball has no reason to renumber because a Hiker
    turned out to be further down the road. Every category sorts on its own and stays where it was
    in the list, which is what keeps the letter series independent."""
    const = sources.parse_headers(root)["Route10"][0]
    raw = markers.build_markers(root, "Route10", const, 320, 1152, keyed=False)
    walked = paths.walked_markers(root, "Route10", raw)

    assert [m["cat"] for m in walked] == [m["cat"] for m in raw]
    assert [m["id"] for m in walked if m["cat"] == "trainer"] != \
        [m["id"] for m in raw if m["cat"] == "trainer"]
    assert sorted(m["id"] for m in walked) == sorted(m["id"] for m in raw)


def test_a_pin_the_route_names_holds_exactly_the_place_it_is_given(root):
    """Route 6's two Jr. Trainers stand shoulder to shoulder, so each is one step from the other's
    waypoint and reads as zero away from it. On nearest-waypoint alone the pair would tie and
    settle on the map file whatever the route said, so naming a cell has to beat standing next to
    one: each takes its own place in the route, and the walk down from the west Bug Catcher reaches
    the lad on the left before the lass beside him."""
    drawn = pins(root, "Route6", "")
    cells = paths.route_cells(root, "Route6")
    ranks = [paths.walk_rank(root, "Route6", grid) for grid in ([10, 21], [11, 21])]

    assert (tuple(drawn["T2"]["grid"]), tuple(drawn["T3"]["grid"])) == ((10, 21), (11, 21))
    assert ranks == [(cells.index((10, 21)), 0), (cells.index((11, 21)), 0)]
    assert ranks[0] != ranks[1], "adjacency must not collapse two named pins onto one rank"


def test_a_cell_no_doorway_reaches_sorts_last(root):
    """Route 3's top-left corner is solid rock the player never stands on. Nothing on a real map
    should rank there, but a marker that somehow does falls to the back rather than tying with the
    trainer by the gate."""
    walled = paths.walk_rank(root, "Route3", [0, 0])

    assert walled[1] == paths.UNREACHED
    assert walled > paths.walk_rank(root, "Route3", pins(root, "Route3", "")["T8"]["grid"])


def test_every_entrance_names_a_doorway_its_map_really_draws(root):
    """The table is written in marker ids, the same strings the walkthrough's step pins use, so a
    typo or a doorway that moves has to fail here rather than silently lettering everyone equal."""
    for label in paths.ROUTES:
        assert len(paths.route_cells(root, label)) == len(paths.ROUTES[label]), label


def test_every_floor_with_pins_to_sort_has_a_route():
    """A newly drawn floor with two or more of anything walked on it needs a doorway, or its pins
    quietly fall back to map-file order and nobody notices. Decks are the standing exception."""
    manifest = json.loads(MANIFEST.read_text())["locations"]
    label_of = {locations.image_name(slug, floor): label
                for slug, maps in locations.location_maps().items()
                for label, floor, _parent in maps}

    missing = set()
    for maps in manifest.values():
        for entry in maps:
            label = label_of.get(entry["name"])
            if label is None or locations.attached(label) or label in paths.ROUTES:
                continue
            counts = Counter(pin["cat"] for pin in entry["markers"])
            if any(counts[cat] > 1 for cat in paths.WALKED):
                missing.add(label)

    assert sorted(missing) == []


def test_the_roster_letters_a_card_the_way_its_pin_is_lettered(root):
    """The build's own output, not just the helper: the cards ship in walking order wearing the
    walking letters, so T1 on a card and T1 on the map are the same trainer."""
    trainers, _specs = roster.build_roster(root)

    assert [(e["key"], e["opp"]) for e in trainers["route-10"]] == lettered(root, "Route10", "")
