import locations
import markers
import roster
import sources

ROUTE_3 = [
    ("A", "BUG_CATCHER:4", 100, [("010", 10), ("013", 10), ("010", 10)]),
    ("B", "YOUNGSTER:1", 165, [("019", 11), ("023", 11)]),
    ("C", "LASS:1", 135, [("016", 9), ("016", 9)]),
    ("D", "BUG_CATCHER:5", 90, [("013", 9), ("014", 9), ("010", 9), ("011", 9)]),
    ("E", "LASS:2", 150, [("019", 10), ("032", 10)]),
    ("F", "YOUNGSTER:2", 210, [("021", 14)]),
    ("G", "BUG_CATCHER:6", 110, [("010", 11), ("011", 11)]),
    ("H", "LASS:3", 210, [("039", 14)]),
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

    assert checked == 301


def test_gym_floors_are_lettered_nothing(root):
    """A gym renders as a plain screenshot with no pins, so its cards claim no letter."""
    entries, _ = built(root)
    gym = [e for e in entries["pewter-city"] if e["floor"] == "Gym"]

    assert gym and all(e["key"] is None for e in gym)


def test_extra_maps_contribute_cards_without_pins(root):
    """The SS Anne's cabins hold sixteen trainers the ship's own map never draws."""
    entries, _ = built(root)
    ship = entries["ss-anne"]

    assert len(ship) == 16
    assert all(e["key"] is None for e in ship)


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
