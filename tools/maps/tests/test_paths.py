import json
import pathlib
from collections import Counter, deque

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


def test_route_12_walks_the_pier_rather_than_swimming_the_bay(root):
    """Silence Bridge is a pier, so the flood has two ways to get it wrong at once.

    The gate building splits the route in half and the flood cannot walk through it, so from the
    north end alone every pin was unreachable and the page fell back to map-file order: the Jr.
    Trainer at the very bottom read as T3, above the Rocker and two Fishermen he stands well past.
    Naming the gate's south door fixes that, but the bay is open water the flood swims, which still
    hands over the Fisherman on the east planks before the one two rows above him on the west side.
    The seven are named outright, so the letters run the way the boards do: down the east side, back
    west, down to the Rocker, into the Cut-walled alcove, and out at the bottom."""
    assert [tuple(pins(root, "Route12", "")[key]["grid"]) for key in
            ("T1", "T2", "T3", "T4", "T5", "T6", "T7")] == [
        (14, 31), (5, 39), (12, 40), (9, 52), (14, 76), (6, 87), (11, 92)]


def test_route_13_takes_the_southwest_pocket_on_the_way_to_the_west_gate(root):
    """The tail of Route 13, which the flood reads backwards.

    Its exit is on the west side, so the pocket in the southwest corner (a Bird Keeper standing
    over the buried PP Up) is a detour taken on the way past, and the Biker beside the gate is the
    last trainer on the road. Ranked from the doorway alone all three came out the other way up."""
    assert [tuple(pins(root, "Route13", "")[key]["grid"]) for key in ("T8", "T9", "T10")] == [
        (7, 13), (12, 4), (10, 7)]


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


def test_route_9_walks_the_low_road_before_the_pocket_above_it(root):
    """Route 9 is crossed on one-way ledges, which the flood reads as walls it can climb, so it
    ranked all nine on how far east they stand. Walked, you reach the Youngster on the low road
    before the Bug Catcher up in the northern bowl, and the Hiker down in the southeast hollow
    before the Bug Catcher on the shelf above him; straight distance had both pairs the other way
    about."""
    assert lettered(root, "Route9", "") == [
        ("T1", "JR_TRAINER_F:5"), ("T2", "HIKER:11"), ("T3", "YOUNGSTER:14"),
        ("T4", "BUG_CATCHER:13"), ("T5", "HIKER:5"), ("T6", "BUG_CATCHER:14"),
        ("T7", "JR_TRAINER_M:8"), ("T8", "HIKER:6"), ("T9", "JR_TRAINER_F:6")]


def test_route_8_takes_its_column_of_four_from_the_top(root):
    """Four of Route 8's nine stand one above the other in the corridor halfway along, and they
    are cleared in a single pass down it: you come west along the top of the field and take the
    north end first. The flood walks in along the bottom row instead, which lettered the column
    upside down and described a walk that climbs it only to come back down for the road west."""
    column = [pin for pin in lettered(root, "Route8", "") if pin[0] in {"T4", "T5", "T6", "T7"}]

    assert column == [("T4", "LASS:13"), ("T5", "SUPER_NERD:5"),
                      ("T6", "LASS:14"), ("T7", "LASS:15")]
    assert [tuple(pins(root, "Route8", "")[key]["grid"]) for key in ("T4", "T5", "T6", "T7")] == [
        (26, 3), (26, 4), (26, 5), (26, 6)]


def test_rock_tunnel_1f_is_lettered_stretch_by_sealed_stretch(root):
    """1F is three stretches with no way between them on foot: the north mouth's, which holds the
    Pokémaniac and the ladder down; the middle pocket, reached only by climbing back up from B1F;
    and the southern one that owns the mouth to Lavender. The flood walks the rock between them,
    which put a middle-pocket Hiker ahead of the Pokémaniac you meet before ever leaving the first
    stretch."""
    assert lettered(root, "RockTunnel1F", "1F") == [
        ("T1", "POKEMANIAC:7"), ("T2", "HIKER:12"), ("T3", "HIKER:13"), ("T4", "HIKER:14"),
        ("T5", "JR_TRAINER_F:17"), ("T6", "JR_TRAINER_F:19"), ("T7", "JR_TRAINER_F:18")]


def test_rock_tunnel_b1f_is_lettered_around_the_loop_it_is_walked(root):
    """B1F is crossed twice, with the climb into 1F's middle pocket between the halves: in at the
    southeast ladder, west along the bottom, up the middle and back east for the ladder under that
    pocket, then down its other ladder and west again for the top-left corner. Sorted on distance
    from the one door, the Jr. Trainer at the west end of the bottom run came fifth, behind three
    trainers the walk does not reach until it has turned around."""
    assert lettered(root, "RockTunnelB1F", "B1F") == [
        ("T1", "POKEMANIAC:5"), ("T2", "JR_TRAINER_F:10"), ("T3", "POKEMANIAC:4"),
        ("T4", "HIKER:10"), ("T5", "HIKER:11"), ("T6", "JR_TRAINER_F:9"),
        ("T7", "HIKER:9"), ("T8", "POKEMANIAC:3")]


def test_a_gym_ends_on_its_leader(root):
    """Every gym is one room off one door, so the walk always finishes at the back of it and the
    leader wears the last letter rather than whichever one the map file happened to give them."""
    for label, floor, leader in (("PewterGym", "Gym", "BROCK:1"),
                                 ("CeruleanGym", "Gym", "MISTY:1"),
                                 ("SaffronGym", "Gym", "SABRINA:1")):
        assert lettered(root, label, floor)[-1][1] == leader, label


def test_the_fighting_dojo_is_walked_from_the_door_up_to_the_master(root):
    """Not a gym, but the same one room off one door: the four Black Belts letter up the room in
    the order you pass their lines, and the Karate Master at the back wears the last letter."""
    walk = lettered(root, "FightingDojo", "Dojo")

    assert [opp for _key, opp in walk] == [
        "BLACKBELT:5", "BLACKBELT:3", "BLACKBELT:4", "BLACKBELT:2", "BLACKBELT:1"]
    assert [tuple(pins(root, "FightingDojo", "Dojo")[key]["grid"]) for key in
            ("T1", "T2", "T3", "T4", "T5")] == [(5, 7), (3, 6), (5, 5), (3, 4), (5, 3)]


def test_celadon_gyms_sealed_chamber_is_lettered_the_way_you_walk_it(root):
    """Erika's four sit in a chamber walled off by hedges, and a gym hedge is solid to the shipped
    collision, so the flood reaches the four in the open and stops. Left to itself the chamber fell
    back to map-file order, which put the Beauty on the west side ahead of the Cooltrainer you pass
    first. The route names the chamber outright, so the letters now run the way you cross it."""
    assert lettered(root, "CeladonGym", "Gym") == [
        ("T1", "LASS:17"), ("T2", "BEAUTY:1"), ("T3", "BEAUTY:2"), ("T4", "JR_TRAINER_F:11"),
        ("T5", "ERIKA:1"), ("T6", "LASS:18"), ("T7", "COOLTRAINER_F:1"), ("T8", "BEAUTY:3")]


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


def test_the_hideout_b1f_is_lettered_across_its_three_sealed_rooms(root):
    """B1F is one map and three rooms, and no two of them join up in play. Off the Game Corner
    stairs you take the Rocket on the west corridor and the one holding the east doorway; the
    southwest room is reached only by climbing back up from B2F; and the fifth is met stepping out
    of the lift, on the far side of a door that only opens once he is beaten. The flood walks
    straight through that door, so measured from the entrance it read the east Rocket first and put
    the two the guide meets last in the middle."""
    assert lettered(root, "RocketHideoutB1F", "B1F") == [
        ("T1", "ROCKET:9"), ("T2", "ROCKET:8"), ("T3", "ROCKET:11"),
        ("T4", "ROCKET:10"), ("T5", "ROCKET:12")]
    assert [tuple(pins(root, "RocketHideoutB1F", "B1F", cat="item")[key]["grid"])
            for key in ("I1", "I2")] == [(11, 14), (9, 17)]


def test_the_hideout_mazes_letter_their_balls_the_way_the_arrows_deal_them(root):
    """An arrow tile is plain floor to the shipped collision, so the flood strolls across a maze
    the player can only cross by being fired at a wall. On B2F that put the Nugget by the north
    wall first and the Moon Stone in the far corner third, where the arrows hand them over the
    other way about; on B3F it read the Rare Candy before the TM down the east wall, which is
    picked up before the maze is entered at all."""
    b2f = pins(root, "RocketHideoutB2F", "B2F", cat="item")
    b3f = pins(root, "RocketHideoutB3F", "B3F", cat="item")

    assert [b2f[key]["name"] for key in ("I1", "I2", "I3", "I4")] == [
        "Moon Stone", "Nugget", "TM Horn Drill", "Super Potion"]
    assert [b3f[key]["name"] for key in ("I1", "I2")] == ["TM Double Edge", "Rare Candy"]


def test_the_hideout_b4f_splits_its_balls_between_the_stairs_and_the_lift(root):
    """B4F is walked twice and the second visit arrives by lift, past a gate the stairs cannot
    reach. The first sweep takes the HP Up, the TM and the Lift Key in the west wing; the Iron and
    the Silph Scope wait for the lift, so they letter last however near the stairs they sit."""
    items = pins(root, "RocketHideoutB4F", "B4F", cat="item")

    assert [items[key]["name"] for key in ("I1", "I2", "I3", "I4", "I5")] == [
        "HP Up", "TM Razor Wind", "Lift Key", "Iron", "Silph Scope"]
    assert lettered(root, "RocketHideoutB4F", "B4F") == [("T1", "ROCKET:18"), ("T2", "GIOVANNI:1")]


def test_the_tower_letters_each_floor_the_way_its_lap_is_walked(root):
    """Every Pokemon Tower floor is a ring of gravestone rows with one doorway in and another out,
    so the walk is a lap and plain distance from the door reads most of it backwards. On 3F the
    lap climbs north to the Channeler under the Escape Rope before the long drop to the one on the
    bottom row; the flood, measuring from the west stairs, hands over the bottom row first."""
    assert lettered(root, "PokemonTower3F", "3F") == [
        ("T1", "CHANNELER:5"), ("T2", "CHANNELER:8"), ("T3", "CHANNELER:6")]
    assert lettered(root, "PokemonTower5F", "5F") == [
        ("T1", "CHANNELER:16"), ("T2", "CHANNELER:14"),
        ("T3", "CHANNELER:17"), ("T4", "CHANNELER:18")]


def test_tower_4f_takes_the_awakening_before_doubling_back_for_the_hp_up(root):
    """The three balls sit in an L: the Elixir mid-floor, the Awakening one row west of it, and the
    HP Up alone in a notch on the south edge. You clear the row before dropping into the notch, so
    the Awakening is second; distance from the east stairs puts the notch there instead."""
    items = pins(root, "PokemonTower4F", "4F", cat="item")

    assert [items[key]["name"] for key in ("I1", "I2", "I3")] == ["Elixir", "Awakening", "HP Up"]
    assert lettered(root, "PokemonTower4F", "4F") == [
        ("T1", "CHANNELER:10"), ("T2", "CHANNELER:12"), ("T3", "CHANNELER:9")]


def test_silph_5f_letters_the_lift_visit_before_the_stairs_visit(root):
    """5F is walked twice and the two halves are nothing like each other. The lift comes up first,
    for the Elixir in the plant pots, the Rocket the warp pad drops you behind and the Card Key
    down the corridor he was blocking; the rest of the floor waits for the stairs up from 4F. The
    corridor has one open end, a warp tile, so the flood cannot walk in at all and measured the
    Rocket at the far end of a lap of the whole floor: it lettered him last of four and gave the
    Card Key to the guide before the man standing over it."""
    assert lettered(root, "SilphCo5F", "5F") == [
        ("T1", "ROCKET:28"), ("T2", "ROCKET:29"), ("T3", "JUGGLER:1"), ("T4", "SCIENTIST:6")]
    assert [pins(root, "SilphCo5F", "5F", cat="item")[key]["name"] for key in ("I1", "I2", "I3")] \
        == ["Card Key", "Protein", "TM Take Down"]


def test_silph_letters_the_floors_the_card_key_reorders(root):
    """A Card Key barrier is open floor to the shipped collision, so the flood steps through every
    sealed room as if it were an alcove off the corridor beside it, and four floors came out in an
    order nobody walks. 2F is entered from the lift and cleared clockwise, so the Scientist in the
    south room comes before the Rocket between the tables the flood ranks nearer. 4F's three balls
    share one pocket entered from the south, so the Full Heal is a step off the doorway and the
    other two are up the column above it. 7F takes the two sealed rooms south of the stairs before
    crossing west. 9F goes straight down the corridor left of the stairs, so the Rocket at its foot
    and the Rocket past the nurse's room both come before the Scientist nearer the door."""
    assert lettered(root, "SilphCo2F", "2F") == [
        ("T1", "ROCKET:24"), ("T2", "SCIENTIST:3"), ("T3", "ROCKET:23"), ("T4", "SCIENTIST:2")]
    assert [pins(root, "SilphCo4F", "4F", cat="item")[key]["name"] for key in ("I1", "I2", "I3")] \
        == ["Full Heal", "Max Revive", "Escape Rope"]
    assert lettered(root, "SilphCo7F", "7F") == [
        ("T1", "ROCKET:33"), ("T2", "ROCKET:34"), ("T3", "ROCKET:32"), ("T4", "SCIENTIST:8")]
    assert [pins(root, "SilphCo7F", "7F", cat="item")[key]["name"] for key in ("I1", "I2")] == [
        "TM Swords Dance", "Calcium"]
    assert lettered(root, "SilphCo9F", "9F") == [
        ("T1", "ROCKET:38"), ("T2", "ROCKET:37"), ("T3", "SCIENTIST:10")]


def test_silph_10f_circles_the_crates_rather_than_reaching_across_them(root):
    """The three balls on 10F sit in the gaps of a block of crates filling the southwest room, so
    they are collected by walking round the outside: down the east side for the Carbos, along the
    bottom for the Rare Candy, up the west wall past the Earthquake on the way out. The flood
    measures each ball through the crates and hands them over in the opposite order."""
    items = pins(root, "SilphCo10F", "10F", cat="item")

    assert [items[key]["name"] for key in ("I1", "I2", "I3")] == [
        "Carbos", "Rare Candy", "TM Earthquake"]


def test_safari_area_1_is_lettered_up_the_stair_the_player_climbs(root):
    """You come into Area 1 at the southwest corner, run the bottom wall east and climb the first
    stair onto the mount, so the Carbos is the first ball in reach and the Egg Bomb west of it the
    second. The flood reads the Egg Bomb as nearest the entrance because it measures across the
    wall the stair goes round. The Full Restore is last: it sits four tiles above the Carbos, but
    the walk takes the northwest corner before doubling back for it."""
    items = pins(root, "SafariZoneEast", "East", cat="item")

    assert [items[key]["name"] for key in ("I1", "I2", "I3", "I4")] == [
        "Carbos", "TM Egg Bomb", "Max Potion", "Full Restore"]


def test_cycling_road_is_lettered_one_lane_at_a_time(root):
    """Route 17 is three roads, not one: barriers run down the middle of the long stretch at
    columns 4-6 and 10-12, so the right lane, the middle and the left never meet between the foot
    and the top, so each is taken on its own: the right and the middle are climbed from the foot,
    and the left is come down, because the middle tops out level with where it opens. That is why
    the letters run up, up, then back down. Distance from the south gate sees none of it and deals
    the road out in height bands, hopping a barrier whenever two pins sit level with each other."""
    trainers = pins(root, "Route17", "", cat="trainer")
    hidden = pins(root, "Route17", "", cat="hidden")

    assert [tuple(trainers[f"T{n}"]["grid"]) for n in range(1, 11)] == [
        (10, 118), (14, 98), (17, 58), (14, 34), (7, 32),
        (2, 68), (5, 98), (4, 18), (12, 19), (11, 16)]
    assert [hidden[f"H{n}"]["name"] for n in range(1, 6)] == [
        "Max Elixir", "PP Up", "Full Restore", "Max Revive", "Rare Candy"]


def test_route_16_letters_its_riders_the_way_you_walk_back_to_celadon(root):
    """All six sit west of where you surface off Cycling Road, between its top gate and the Fly
    house, with Celadon the other way. You walk the strip out and back to clear them, so they are
    lettered west to east: that is the order you meet them on the way home, and the order the far
    one is furthest from rather than nearest."""
    drawn = pins(root, "Route16", "")

    assert [tuple(drawn[f"T{n}"]["grid"]) for n in range(1, 7)] == [
        (3, 12), (6, 10), (9, 11), (11, 12), (14, 13), (17, 12)]


def test_route_18_takes_the_upper_bird_keeper_before_the_one_below_it(root):
    """The three Bird Keepers sit in a cluster by the Fuchsia gate, one out west and a pair on the
    right. Distance alone splits that pair the wrong way round, putting the one down on the sand
    ahead of the one on the shelf above it, which is not the order either end of the route meets
    them in."""
    drawn = pins(root, "Route18", "")

    assert [tuple(drawn[key]["grid"]) for key in ("T1", "T2", "T3")] == [(36, 11), (42, 13), (40, 15)]


def test_safari_area_3_letters_its_second_visit_from_the_east_door(root):
    """Area 3 is walked twice. The first trip drops in from Area 2 at the top and sweeps the upper
    band west, so the Gold Teeth and TM32 letter first. The second comes back from the Center once
    Surf is legal, and from that east door the Max Revive is a few steps away while the Max Potion
    is over the mount: measured from the north door alone the flood hands them out the other way
    round."""
    items = pins(root, "SafariZoneWest", "West", cat="item")

    assert [items[key]["name"] for key in ("I1", "I2", "I3", "I4")] == [
        "Gold Teeth", "TM Double Team", "Max Revive", "Max Potion"]


def test_safari_area_2_takes_tm40_on_the_climb_and_the_protein_at_the_top(root):
    """Area 2 is entered on the east edge and crossed behind the fences by its second stair. TM40
    stands on that climb and the Protein is past the top wall, through the one gap in it, so the
    letters run TM40 then Protein; measured from the doorway alone the two tie and fall back the
    other way."""
    items = pins(root, "SafariZoneNorth", "North", cat="item")

    assert [items[key]["name"] for key in ("I1", "I2")] == ["TM Skull Bash", "Protein"]


def test_tower_6f_picks_up_the_x_accuracy_on_the_way_in_not_the_rare_candy(root):
    """The X Accuracy is a short drop south off the first Channeler, a few tiles from the doorway.
    The Rare Candy is over on the west side, reached by going up over the top of the floor and back
    down, and its ball plugs the only gap through to the stairs, so it is the last thing collected
    even though the flood rates it the nearer of the two."""
    items = pins(root, "PokemonTower6F", "6F", cat="item")

    assert [items[key]["name"] for key in ("I1", "I2")] == ["X Accuracy", "Rare Candy"]
    assert lettered(root, "PokemonTower6F", "6F") == [
        ("T1", "CHANNELER:19"), ("T2", "CHANNELER:21"), ("T3", "CHANNELER:20")]


def test_the_rare_candy_ball_really_is_6fs_only_way_through(root):
    """Why the Rare Candy letters last however near the door it sits, and why the step tells you
    you have to take it: its ball stands in the one gap in the gravestone wall between the floor
    and the stairs down. The shipped collision does not know a ball occupies a tile, so the flood
    strolls past it; block that one cell and the stairs fall off the map."""
    label = "PokemonTower6F"
    const, tileset = sources.parse_headers(root)[label]
    _index, width_blocks, _height = sources.parse_map_constants(root)[0][const]
    width_cells, height_cells = markers.map_cells(root, const)

    def open_cell(cell):
        return 0 <= cell[0] < width_cells and 0 <= cell[1] < height_cells and \
            markers.cell_is_walkable(root, label, tileset, width_blocks, cell)

    def flood(start, blocked):
        seen, queue = {start}, deque([start])
        while queue:
            x, y = queue.popleft()
            for cell in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if cell != blocked and cell not in seen and open_cell(cell):
                    seen.add(cell)
                    queue.append(cell)
        return seen

    door, stairs, candy = (18, 9), (9, 16), (6, 8)

    assert stairs not in flood(door, candy)
    assert stairs in flood(door, None)
