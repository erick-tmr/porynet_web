import json
import pathlib

import pytest

import compositor
import follower
import generators
import markers
import sources

SPECS = pathlib.Path(__file__).resolve().parents[1] / "specs"


@pytest.fixture
def pikachu_follower():
    """Configure the tool with Yellow's Pikachu follower for the duration of a test, then restore
    the default (no follower), so these tests do not leak the setting into the rest of the suite."""
    saved = follower.FOLLOWER_SPRITE
    follower.FOLLOWER_SPRITE = "SPRITE_PIKACHU"
    try:
        yield
    finally:
        follower.FOLLOWER_SPRITE = saved


def _trade_spec(name):
    entries = json.loads((SPECS / "trades.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _step_shot(name):
    entries = json.loads((SPECS / "step_shots.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _mew_spec(name):
    entries = json.loads((SPECS / "mew_glitch.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _item_spec(name):
    entries = json.loads((SPECS / "overworld_items.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _route24_grass_trigger(root):
    """The Jr. Trainer the Mew glitch triggers on: the OPP_JR_TRAINER_M standing in Route 24's tall
    grass, not the identically-classed one out on the bridge planks."""
    grass = compositor.grass_cells(root, "Route24")
    objs = sources.parse_object_events(root, "Route24", include_battlers=True)
    trainers = [o for o in objs if o["opp_class"] == "JR_TRAINER_M" and o["grid"] in grass]
    assert len(trainers) == 1, "exactly one Jr. Trainer stands in the grass"
    return trainers[0]["grid"]


def _cell_walkable(root, map_label, cell):
    const, tileset = sources.parse_headers(root)[map_label]
    width_blocks = sources.parse_map_constants(root)[0][const][1]
    return markers.cell_is_walkable(root, map_label, tileset, width_blocks, cell)


def test_resolve_sprite_const_and_dir(root):
    spr = generators._resolve_sprite(root, {"sprite": "SPRITE_RED", "grid": [1, 2], "dir": "RIGHT"})
    assert spr == {"file": "red", "frame": 2, "grid": [1, 2], "flip": True}


def test_resolve_sprite_explicit_frame(root):
    spr = generators._resolve_sprite(root, {"sprite": "red", "grid": [0, 0], "frame": 1})
    assert spr["file"] == "red" and spr["frame"] == 1 and spr["flip"] is False


def test_auto_npcs(root):
    npcs = generators.auto_npcs(root, "PalletTown")
    assert {n["file"] for n in npcs} == {"girl", "fisher"}


def test_dialog_lines_found_item():
    assert generators._dialog_lines({"found_item": "ANTIDOTE"}) == ["PORYNET found", "ANTIDOTE!"]


def test_dialog_lines_substitutes_names():
    assert generators._dialog_lines({"lines": ["<PLAYER> vs <RIVAL>"]}) == ["PORYNET vs BLUE"]


def test_gen_battle_rival_name(root):
    image, name, meta = generators.generate(
        root, {"type": "battle", "name": "b", "opponent": "RIVAL1", "rival_name": "BLUE"})
    assert image.size == (160, 144) and name == "b" and meta == {}


def test_gen_map_scene_dims(root):
    image, _, _ = generators.generate(
        root, {"type": "npc", "name": "p", "map": "PalletTown", "auto_npcs": True})
    assert image.size == (320, 288)


def test_gen_screen_scene_dims(root):
    image, _, _ = generators.generate(
        root, {"type": "dialog", "name": "d", "map": "ViridianForest", "player": [16, 42],
               "dialog": {"found_item": "ANTIDOTE"}})
    assert image.size == (160, 144)


def test_auto_npcs_includes_trainers_when_asked(root):
    plain = generators.auto_npcs(root, "ViridianForest")
    withtrainers = generators.auto_npcs(root, "ViridianForest", battlers=True)
    assert len(withtrainers) > len(plain), "battlers=True adds the map's trainers"


def test_a_scene_draws_the_trainer_its_caption_points_at(root):
    """Regression: the hidden-Potion shot reads 'one square west of the Bug Catcher', so the Bug
    Catcher (a trainer at [2, 18], the tile east of the Potion at [1, 18]) has to be on screen."""
    spec = {"type": "dialog", "name": "d", "map": "ViridianForest", "player": [1, 19],
            "marker": [1, 18], "dialog": {"found_item": "POTION"}}
    grids = [s["grid"] for s in generators._screen_sprites(root, spec)]

    assert [1, 19] in grids, "the hero is drawn"
    assert [2, 18] in grids, "the Bug Catcher landmark is drawn"


def test_a_hand_composed_scene_keeps_only_its_own_cast(root):
    """A rival face-off places its rival by hand; the map's other people must not crowd in."""
    hero, rival = [7, 5], [7, 3]
    spec = {"type": "screen", "name": "r", "map": "CeruleanCity", "player": hero,
            "sprites": [{"sprite": "SPRITE_BLUE", "grid": rival, "dir": "DOWN"}]}
    grids = [s["grid"] for s in generators._screen_sprites(root, spec)]

    assert sorted(grids) == sorted([hero, rival]), "only the hero and the placed rival"


def test_a_scene_never_double_draws_an_npc_under_a_placed_sprite(root):
    """Opting a hand-composed scene into auto NPCs must still not stack a second sprite on a cell
    the scene already placed one on."""
    fisher = [11, 14]  # Pallet Town's fisher object
    spec = {"type": "screen", "name": "p", "map": "PalletTown", "player": [10, 4],
            "auto_npcs": True, "sprites": [{"sprite": "SPRITE_FISHER", "grid": fisher}]}
    grids = [s["grid"] for s in generators._screen_sprites(root, spec)]

    assert grids.count(fisher) == 1, "the placed sprite wins its cell; the auto one is dropped"


def test_trade_inside_scene_draws_its_trade_npc(root):
    # The Route 2 trade-house interior must show the SCIENTIST who runs the Mr. Mime trade
    # (object_event 2, 4 in data/maps/objects/Route2TradeHouse.asm) beside the hero.
    spec = _trade_spec("route-2-trade-house-inside")
    grids = [s["grid"] for s in generators._screen_sprites(root, spec)]
    assert spec["player"] in grids, "the hero is drawn"
    assert [2, 4] in grids, "the trade SCIENTIST is drawn as the scene's subject"


def test_route_2_trade_hero_stands_below_the_scientist_not_across_the_table(root):
    # Regression: the hero used to sit on the far chair at [5, 4] and talk to the SCIENTIST
    # (object_event 2, 4) across the counter table, which no one can walk through. The trade is
    # face-to-face from the plain floor tile directly below the scientist (the one adjacent side
    # this room leaves open), facing up. [2, 4] and [5, 4] are both chair tiles anyway.
    spec = _trade_spec("route-2-trade-house-inside")
    hero, scientist = tuple(spec["player"]), (2, 4)
    assert _cell_walkable(root, spec["map"], hero), "the hero stands on real floor"
    assert (hero[0] - scientist[0], hero[1] - scientist[1]) == (0, 1), "one tile below the scientist"
    assert spec["player_dir"] == "UP", "facing up to talk to the scientist, no table between them"


def test_leave_mt_moon_frames_the_cerulean_side_exit(root):
    # Regression: the "Leave Mt. Moon" shot used to sit the hero below the west entrance
    # (MT_MOON_1F, the door you walk in through) instead of the Cerulean-side exit you come out of.
    # Both are cave mouths a few tiles apart on Route 4, so it is an easy shot to aim at the wrong
    # one. Derive the two warps from the game data so the shot stays pinned to the real exit tile.
    warps = sources.parse_warp_events(root, "Route4")
    exit_x, exit_y = next((x, y) for x, y, dest, _ in warps if dest == "MT_MOON_B1F")
    entrance_x = next(x for x, _, dest, _ in warps if dest == "MT_MOON_1F")
    assert exit_x != entrance_x  # the premise: the two cave mouths are distinct columns

    spec = _step_shot("route-4-exit")
    hero = tuple(spec["player"])
    assert _cell_walkable(root, spec["map"], hero), "the hero stands on real plateau floor"
    assert hero == (exit_x, exit_y + 1), "one tile out of the Cerulean-side exit"
    assert hero[0] != entrance_x, "never framed on the west entrance"
    assert spec["player_dir"] == "DOWN", "facing the ledges you drop east toward Cerulean"


def test_viridian_hidden_potion_hero_approaches_from_the_open_exit_side(root):
    # Regression: an auto-placement pass flipped this shot's hero to [13, 4], west of the item,
    # into the dead-end nook the lone tree walls off. Both sides read as walkable to the collision
    # check (the west nook connects back to town by a long detour), so only a curated pin catches
    # it: the reviewed approach is from the open north-exit path to the east, standing one tile
    # right of the item and facing left into it.
    spec = _item_spec("viridian-city-hidden-potion")
    hero, item = tuple(spec["player"]), tuple(spec["marker"])
    assert _cell_walkable(root, spec["map"], hero), "the hero stands on real path floor"
    assert (hero[0] - item[0], hero[1] - item[1]) == (1, 0), "one tile east of the item, not the west nook"
    assert spec["player_dir"] == "LEFT", "facing west into the tree, from the open exit path"


def test_trade_house_scene_places_the_hero_at_the_door(root):
    # The overworld "where" shot for the trade house stands the hero at its door on Route 2
    # (warp_event 15, 19 in data/maps/objects/Route2.asm). The route's own people ride along
    # as landmarks, so we only pin the hero's cell here.
    spec = _trade_spec("route-2-trade-house")
    grids = [s["grid"] for s in generators._screen_sprites(root, spec)]
    assert spec["player"] in grids, "the hero stands one tile below the trade-house door"


# Scenes where the hero stands on a specific tile to interact with something: a trade counter, an
# item, a trainer it faces. A render draws the hero on a counter, boulder or desk all the same, so
# these are guarded to keep it on real floor. Directional step shots frame a landmark rather than
# an interaction and are out of scope.
INTERACTION_SPEC_FILES = ["trades.json", "hidden_items.json", "trainers.json", "overworld_items.json"]


def test_interaction_scenes_stand_the_hero_on_a_walkable_tile(root):
    # Regressions this catches: the Dewgong hero on the Cinnabar lab counter, the Mr. Mime hero on
    # the Route 2 trade-house counter, the Moon Stone hero on a boulder, the Giovanni hero on his
    # desk. The hero is placed via `player`, or as a SPRITE_RED sprite in a hand-composed scene.
    for fname in INTERACTION_SPEC_FILES:
        for spec in json.loads((SPECS / fname).read_text()):
            cells = [tuple(spec["player"])] if "player" in spec else []
            cells += [tuple(s["grid"]) for s in spec.get("sprites", []) if s.get("sprite") == "SPRITE_RED"]
            for cell in cells:
                assert _cell_walkable(root, spec["map"], cell), \
                    f"{spec['name']} ({fname}): hero cell {cell} on {spec['map']} is not walkable floor"


def test_collision_flags_the_counter_the_dewgong_hero_once_sat_on(root):
    # Locks the collision check: the Beauty stands on open floor, but the counter tile the hero
    # was mistakenly placed on ([5, 4] in CinnabarLabTradeRoom) reads as blocked.
    assert _cell_walkable(root, "CinnabarLabTradeRoom", (5, 5)), "the Beauty stands on floor"
    assert not _cell_walkable(root, "CinnabarLabTradeRoom", (5, 4)), "[5, 4] is the counter"


def test_every_trade_scene_is_a_uniquely_named_screen():
    entries = json.loads((SPECS / "trades.json").read_text())
    assert len(entries) == 12, "5 overworld + 7 interior trade scenes"
    assert all(s["type"] == "screen" for s in entries)
    names = [s["name"] for s in entries]
    assert len(names) == len(set(names)), "scene names are unique keys in the manifest"


def test_screen_scene_gets_the_configured_follower_behind_the_hero(root, pikachu_follower):
    # With Yellow's Pikachu configured, a plain overworld screen trails it one tile behind the
    # hero (the hero at [13, 24] faces up -> Pikachu on [13, 25]).
    spec = {"type": "screen", "name": "t", "map": "Route1", "player": [13, 24], "player_dir": "UP"}
    trailing = generators._follower(root, spec, spec["player"], "UP",
                                    generators._screen_sprites(root, spec))
    assert trailing == {"file": "pikachu", "frame": 1, "grid": [13, 25], "flip": False}


def test_no_follower_when_the_game_configures_none(root):
    # The default is no follower (Red/Blue), so the same hero scene draws nobody trailing.
    spec = {"type": "screen", "name": "t", "map": "Route1", "player": [13, 24], "player_dir": "UP"}
    assert follower.FOLLOWER_SPRITE is None
    assert generators._follower(root, spec, spec["player"], "UP", []) is None


def test_a_scene_can_opt_out_of_the_follower(root, pikachu_follower):
    spec = {"type": "screen", "name": "t", "map": "Route1", "player": [13, 24], "follower": False}
    assert generators._follower(root, spec, spec["player"], "UP", []) is None


def test_a_scene_can_name_its_own_follower(root):
    # `follower` as a sprite id overrides the game default (even when it is None), so a scene can
    # trail any Gen 1 overworld sprite it likes.
    spec = {"type": "screen", "name": "t", "map": "Route1", "player": [13, 24],
            "follower": "SPRITE_OAK"}
    trailing = generators._follower(root, spec, spec["player"], "UP", [])
    assert trailing["file"] == "oak"


def test_a_scene_that_stages_the_follower_itself_gets_no_second_one(root, pikachu_follower):
    # The Jigglypuff trivia hand-places a sleeping Pikachu, so the auto-follower must stand down
    # rather than trail a duplicate behind the hero.
    spec = {"type": "screen", "name": "t", "map": "PewterPokecenter", "player": [2, 3],
            "player_dir": "LEFT",
            "sprites": [{"sprite": "SPRITE_PIKACHU", "grid": [3, 3], "dir": "DOWN"}]}
    assert generators._follower(root, spec, spec["player"], "LEFT", []) is None


def test_the_follower_changes_what_a_screen_scene_draws(root, pikachu_follower):
    base = {"type": "screen", "name": "t", "map": "Route1", "player": [13, 24], "player_dir": "UP"}
    with_pika, _, _ = generators.generate(root, base)
    without_pika, _, _ = generators.generate(root, {**base, "follower": False})
    assert list(with_pika.getdata()) != list(without_pika.getdata()), "the follower is composited"


def test_a_map_scene_trails_the_follower_behind_the_hero_sprite(root, pikachu_follower):
    # A full-map scene that places the hero as a SPRITE_RED sprite trails the follower behind it too.
    base = {"type": "map", "name": "m", "map": "PalletTown",
            "sprites": [{"sprite": "SPRITE_RED", "grid": [10, 3], "dir": "UP"}]}
    with_pika, _, _ = generators.generate(root, base)
    without_pika, _, _ = generators.generate(root, {**base, "follower": False})
    assert list(with_pika.getdata()) != list(without_pika.getdata())


def test_a_map_scene_without_a_hero_draws_no_follower(root, pikachu_follower):
    # No SPRITE_RED on the map means no hero to follow, so nothing changes with the flag off.
    base = {"type": "npc", "name": "m", "map": "PalletTown", "auto_npcs": True}
    with_flag, _, _ = generators.generate(root, base)
    without_flag, _, _ = generators.generate(root, {**base, "follower": False})
    assert list(with_flag.getdata()) == list(without_flag.getdata())


def test_unknown_type_raises(root):
    with pytest.raises(ValueError):
        generators.generate(root, {"type": "bogus", "name": "x"})


def test_mew_start_shows_the_trigger_trainer_with_the_bang(root):
    # The GLITCH 3 caption is about the "!" the grass Jr. Trainer throws when he spots you, so he
    # and his shock emote are the whole composed cast: no bridge crowd, no other Route 24 people.
    spec = _mew_spec("mew-glitch-start")
    trigger = _route24_grass_trigger(root)
    placed = spec["sprites"]
    assert len(placed) == 1 and tuple(placed[0]["grid"]) == trigger, "the trigger trainer is placed"
    assert placed[0]["emote"] == "shock", "he throws the ! the caption points at"
    grids = [tuple(s["grid"]) for s in generators._screen_sprites(root, spec)]
    assert grids == [tuple(spec["player"]), trigger], "hand-composed: only the hero and the trigger"


def test_mew_lineup_keeps_the_trigger_trainer_offscreen(root):
    # GLITCH 2 lines the hero up in the trigger's column but far enough north that the grass Jr.
    # Trainer sits just off the bottom edge: the glitch needs him offscreen (on screen he just
    # walks over and battles you). Regression against an earlier framing that left him visible.
    spec = _mew_spec("mew-glitch-lineup")
    tx, ty = _route24_grass_trigger(root)
    px, py = spec["player"]
    assert px == tx and py < ty, "lined up in his column, north of him"
    assert spec["player_dir"] == "DOWN", "facing down toward him"
    full, _ = compositor.render_map(root, spec["map"])
    focus_y = spec.get("focus", spec["player"])[1]
    offy = compositor._camera(focus_y * compositor.UNIT_PX, compositor.PLAYER_SCREEN[1],
                              full.height, compositor.SCREEN[1])
    assert ty * compositor.UNIT_PX - offy >= compositor.SCREEN[1], "the trigger sits off the bottom edge"


def test_mew_grass_scenes_stand_the_hero_in_tall_grass(root):
    # Regression: the Abra shot first stood the hero below Route 5's grass patch. These grass scenes
    # (catch an Abra, get spotted) each have to put the hero on real tall grass. The line-up shot is
    # deliberately not here: it stands the hero on the path north of the patch, trainer offscreen.
    for name in ("mew-glitch-abra", "mew-glitch-start"):
        spec = _mew_spec(name)
        assert tuple(spec["player"]) in compositor.grass_cells(root, spec["map"]), \
            f"{name}: hero stands in tall grass"


def test_mew_bridge_arrow_points_at_the_trigger_trainer(root):
    # The Nugget Bridge shot has to flag WHICH Jr. Trainer to leave alone, so a down arrow sits
    # above the grass one (the trigger), not the identically-classed trainers out on the planks.
    spec = _mew_spec("mew-glitch-bridge")
    tx, ty = _route24_grass_trigger(root)
    arrows = spec["arrows"]
    assert len(arrows) == 1, "one arrow"
    ax, ay = arrows[0]["grid"]
    assert ax == tx and ay < ty and arrows[0]["dir"] == "down", "a down arrow above the grass trainer"


def test_mew_center_wears_ceruleans_blue_palette(root):
    # The Cerulean Poke Center interior should inherit Cerulean's blue palette, not the default
    # green, so the heal shot reads as the same city the teleport and return shots do.
    spec = _mew_spec("mew-glitch-center")
    assert spec.get("parent") == "CERULEAN_CITY", "the interior inherits Cerulean's palette"
    const, tileset = sources.parse_headers(root)["CeruleanPokecenter"]
    default_pal = sources.resolve_palette_id(root, const, tileset, None)
    cerulean_pal = sources.resolve_palette_id(root, const, tileset, "CERULEAN_CITY")
    assert cerulean_pal != default_pal, "the parent override actually changes the palette"


def test_mew_scenes_stand_the_hero_on_walkable_floor(root):
    # Regression: the Poke Center heal shot stood the hero on the service counter (3, 2) instead of
    # the floor in front of it. Every Mew scene that places a hero must put them on walkable floor.
    for spec in json.loads((SPECS / "mew_glitch.json").read_text()):
        if "player" not in spec:
            continue
        cell = tuple(spec["player"])
        assert _cell_walkable(root, spec["map"], cell), \
            f"{spec['name']}: hero cell {cell} on {spec['map']} is not walkable floor"


def test_mew_swimmer_battle_is_the_gym_swimmer(root):
    # GLITCH 5 is the face-off with the Cerulean Gym Swimmer (OPP_SWIMMER in CeruleanGym).
    spec = _mew_spec("mew-glitch-swimmer")
    assert spec["type"] == "battle" and spec["opponent"] == "SWIMMER"
    gym = sources.parse_object_events(root, "CeruleanGym", include_battlers=True)
    assert any(o["opp_class"] == "SWIMMER" for o in gym), "the gym really has a Swimmer to fight"
