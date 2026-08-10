import locations
import markers
import roster
import sources

ROUTE_3 = [
    ("T1", "BUG_CATCHER:4", 100, [("010", 10), ("013", 10), ("010", 10)]),
    ("T2", "YOUNGSTER:1", 165, [("019", 11), ("023", 11)]),
    ("T3", "LASS:1", 135, [("016", 9), ("016", 9)]),
    ("T4", "BUG_CATCHER:5", 90, [("013", 9), ("014", 9), ("010", 9), ("011", 9)]),
    ("T5", "LASS:2", 150, [("019", 10), ("032", 10)]),
    ("T6", "YOUNGSTER:2", 210, [("021", 14)]),
    ("T7", "BUG_CATCHER:6", 110, [("010", 11), ("011", 11)]),
    ("T8", "LASS:3", 210, [("039", 14)]),
]


def built(root):
    if not hasattr(built, "cache"):
        built.cache = roster.build_roster(root)
    return built.cache


def test_route_3_reproduces_the_hand_authored_cards(root):
    """The load-bearing test: this one assertion pins the reward formula, both party formats,
    the dex mapping and the card order all at once."""
    entries, _ = built(root)
    got = [(e["key"], e["opp"], e["reward"], [(m["dex"], m["lvl"]) for m in e["team"]])
           for e in entries["route-3"]]

    assert got == ROUTE_3


def test_roster_covers_every_trainer_on_every_map(root):
    entries, specs = built(root)
    total = sum(len(v) for v in entries.values())

    assert total == 323
    assert len(specs) == total


def test_scene_names_are_unique(root):
    _, specs = built(root)
    names = [s["name"] for s in specs]

    assert len(set(names)) == len(names)


def test_scene_names_do_not_collide_with_hand_authored_ones(root):
    import build
    _, specs = built(root)
    generated = {s["name"] for s in specs}

    assert not generated & {s["name"] for s in build.load_specs()}


def test_letters_agree_with_the_pins_on_the_same_map(root):
    """A card and its pin must show the same letter; they are lettered by separate code."""
    entries, _ = built(root)
    headers = sources.parse_headers(root)
    dims, _n, _f = sources.parse_map_constants(root)
    checked = 0

    for slug, maps in locations.location_maps().items():
        for label, floor, _parent in maps:
            if label not in headers:
                continue
            const = headers[label][0]
            _i, blocks_w, blocks_h = dims[const]
            area = locations.image_name(slug, floor)
            pins = {m["id"]: m for m in markers.build_markers(
                root, label, const, blocks_w * 32, blocks_h * 32) if m["cat"] == "trainer"}
            for entry in (e for e in entries.get(slug, []) if e["map"] == area):
                pin = pins[entry["marker"]]
                assert pin["ref"] == entry["opp"]
                if entry["key"]:
                    assert pin["key"] == entry["key"]
                checked += 1

    assert checked == 315  # +14: the cabin trainers now sit on drawn maps


def test_gym_floors_are_keyed_like_any_other_map(root):
    """A gym map draws keyed trainer pins, so its cards claim the same keys: the pin is how you
    tell which card is the Jr. Trainer by the door and which is the leader at the back."""
    entries, _ = built(root)
    gym = [e for e in entries["pewter-city"] if e["floor"] == "Gym"]

    assert [e["key"] for e in gym] == ["T1", "T2"]


def test_the_cabin_trainers_are_pinned_now_that_the_rooms_are_drawn(root):
    """The SS Anne's sixteen trainers used to be cards with no pin, because the cabin maps were
    never rendered. The cabins are drawn now, so only the Bow's lone trainer stays pinless."""
    entries, _ = built(root)
    ship = entries["ss-anne"]

    assert len(ship) == 16
    pinless = [e for e in ship if e["key"] is None]
    assert len(pinless) == 2, "only the SS Anne Bow's two Sailors are still undrawn"
    assert {e["map"] for e in pinless} == {"ss-anne-ssannebow"}
    assert {e["map"] for e in ship if e["key"]} == {
        "ss-anne-1f-rooms", "ss-anne-2f-rooms", "ss-anne-b1f-rooms"}


def test_where_geometry_puts_the_player_in_front_facing_back(root):
    _, specs = built(root)
    spec = next(s for s in specs if s["name"] == "route-3-trainer-10-6")
    sprite = spec["sprites"][0]

    assert sprite["grid"] == [10, 6] and sprite["dir"] == "RIGHT"
    assert sprite["emote"] == "shock"
    assert spec["player"] == [12, 6] and spec["player_dir"] == "LEFT"
    assert spec["focus"] == [11, 6]


def test_a_directionless_trainer_faces_down(root):
    """Viridian Forest's Lass has no facing; the hand-authored scene she replaces chose DOWN."""
    _, specs = built(root)
    spec = next(s for s in specs if s["name"] == "viridian-forest-trainer-2-41")

    assert spec["sprites"][0]["dir"] == "DOWN"
    assert spec["player"] == [2, 43] and spec["player_dir"] == "UP"


def test_every_player_cell_lands_inside_its_map(root):
    _, specs = built(root)
    headers = sources.parse_headers(root)
    dims, _n, _f = sources.parse_map_constants(root)

    for spec in specs:
        _i, blocks_w, blocks_h = dims[headers[spec["map"]][0]]
        x, y = spec["player"]
        assert 0 <= x < blocks_w * 2, spec["name"]
        assert 0 <= y < blocks_h * 2, spec["name"]


def test_no_where_scene_stands_the_hero_on_a_solid_tile(root):
    """The invariant the Viridian Forest Bug Catcher shot broke: a where-scene never draws the
    hero inside a tree or a wall. Every one stands on a tile it could occupy, land or water."""
    _, specs = built(root)
    headers = sources.parse_headers(root)
    dims, _n, _f = sources.parse_map_constants(root)

    for spec in specs:
        const, tileset = headers[spec["map"]]
        _i, blocks_w, _h = dims[const]
        assert markers.cell_is_walkable(root, spec["map"], tileset, blocks_w, spec["player"]), \
            f"{spec['name']} stands the hero on a solid tile at {spec['player']}"


def test_the_hero_steps_off_a_tree_into_the_trainers_line(root):
    """Regression: the Bug Catcher by the north-exit Potion faces a tree, so two cells in front is
    unstandable; the hero falls back one cell to the grass it can actually reach, not [0, 18]."""
    _, specs = built(root)
    spec = next(s for s in specs if s["name"] == "viridian-forest-trainer-2-18")

    assert spec["player"] == [1, 18]


def test_no_where_scene_straddles_the_hero_across_a_hedge(root):
    """The Route 3 Bug Catcher (D) used to stand the hero at [19, 7], a cell open above but with
    its feet on the hedge; every where-scene now stands the hero on the tile the game would, its
    lower-left really walkable."""
    _, specs = built(root)
    headers = sources.parse_headers(root)
    dims, _n, _f = sources.parse_map_constants(root)

    for spec in specs:
        const, tileset = headers[spec["map"]]
        _i, blocks_w, _h = dims[const]
        assert markers.cell_is_standable(root, spec["map"], tileset, blocks_w, spec["player"]), \
            f"{spec['name']} straddles the hero at {spec['player']}"


def test_no_where_scene_stands_the_hero_on_another_object(root):
    """A person or an item ball holds its cell against you, and the render draws the hero over
    whoever is there, so the shot silently loses them."""
    _, specs = built(root)

    for spec in specs:
        taken = {tuple(o["grid"]): o["sprite_const"] for o
                 in sources.parse_object_events(root, spec["map"], include_battlers=True)}
        assert tuple(spec["player"]) not in taken, \
            f"{spec['name']} stands the hero on {taken.get(tuple(spec['player']))}"


def test_the_dojo_hero_stands_between_the_master_and_the_black_belt(root):
    """Regression: the Karate Master's card stood the hero two cells ahead on [5, 5], the cell
    Black Belt 3 occupies, so the shot showed four Black Belts instead of five."""
    _, specs = built(root)
    spec = next(s for s in specs if s["name"] == "saffron-city-fightingdojo-trainer-5-3")

    assert spec["player"] == [5, 4]


def test_the_bug_catcher_hero_steps_off_the_hedge_row(root):
    """Regression for the impossible-tile card: the Route 3 Bug Catcher hero moved off [19, 7]
    (feet on the hedge) up onto [19, 6], the grass row it can actually stand on."""
    _, specs = built(root)
    spec = next(s for s in specs if s["name"] == "route-3-trainer-19-5")

    assert spec["player"] == [19, 6]


def test_a_boxed_in_trainer_gets_a_hero_on_the_nearest_floor(root):
    """The Game Corner Rocket faces the wall behind its poster; nothing in its sightline is
    walkable, so the hero stands on the nearest floor tile beside it, not inside the wall."""
    hero = roster.hero_cell(root, "GameCorner", [9, 5], roster.FACINGS["UP"])

    assert hero == [8, 5]


def test_every_entry_is_complete(root):
    entries, _ = built(root)

    for slug, cards in entries.items():
        for card in cards:
            assert card["reward"] > 0, f"{slug} {card['opp']}"
            assert 1 <= len(card["team"]) <= 6
            assert all(len(m["dex"]) == 3 and m["lvl"] > 0 for m in card["team"])
            assert card["where"].endswith(".png")


def test_a_facing_pair_never_flashes_the_spotted_bubble(root):
    """Route 6's two Jr. Trainers stand on adjacent tiles facing each other, and the game gives
    both an engage distance of 0: they only fight when talked to, so no '!' belongs on either."""
    _, specs = built(root)
    pair = [s for s in specs if s["name"] in ("route-6-trainer-10-21", "route-6-trainer-11-21")]

    assert len(pair) == 2
    for spec in pair:
        assert "emote" not in spec["sprites"][0], spec["name"]


def test_a_trainer_who_watches_the_road_still_flashes_it(root):
    """The same route's Bug Catcher sees four tiles down the path, so its shot keeps the '!'."""
    _, specs = built(root)
    spec = next(s for s in specs if s["name"] == "route-6-trainer-0-15")

    assert spec["sprites"][0]["emote"] == "shock"


def test_a_gym_leader_waits_to_be_talked_to(root):
    """A leader is a trainer object with no header at all, so it must not be read as sight 0 by
    accident and must not flash: Brock does not spot you across the gym."""
    _, specs = built(root)
    spec = next(s for s in specs if s["name"] == "pewter-city-gym-trainer-4-1")

    assert "emote" not in spec["sprites"][0]


def test_sight_ranges_come_from_the_map_script(root):
    sight = sources.parse_trainer_sight(root, "Route6")

    assert sight["TEXT_ROUTE6_COOLTRAINER_M1"] == 0
    assert sight["TEXT_ROUTE6_COOLTRAINER_F1"] == 0
    assert sight["TEXT_ROUTE6_YOUNGSTER1"] == 4


def test_a_map_with_no_trainer_headers_reads_as_nobody_spotting(root):
    """Cinnabar's quiz gym has no trainer headers: its fights start at the question machines."""
    assert sources.parse_trainer_sight(root, "CinnabarGym") == {}
    assert sources.parse_trainer_sight(root, "PalletTown") == {}
