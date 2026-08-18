import json
import pathlib
import re

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


def _trainer_spec(name):
    entries = json.loads((SPECS / "trainers.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _step_shot(name):
    entries = json.loads((SPECS / "step_shots.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _mew_spec(name):
    entries = json.loads((SPECS / "mew_glitch.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _trivia_spec(name):
    entries = json.loads((SPECS / "trivia.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _item_spec(name):
    entries = json.loads((SPECS / "overworld_items.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _gym_spec(name):
    entries = json.loads((SPECS / "gyms.json").read_text())
    return next(s for s in entries if s["name"] == name)


def _trash_can_cells(root):
    """The Vermilion Gym trash cans, read from the map's own hidden events rather than retyped:
    each `GymTrashScript` entry is one can, and its argument is the can's puzzle index."""
    text = (pathlib.Path(root) / "data/events/hidden_events.asm").read_text()
    block = re.search(r"hidden_events_for VERMILION_GYM(.*?)db -1", text, re.S).group(1)
    return {(int(x), int(y)) for x, y in
            re.findall(r"hidden_event\s+(\d+),\s*(\d+),\s*GymTrashScript", block)}


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


def _cell_standable(root, map_label, cell, cut=()):
    const, tileset = sources.parse_headers(root)[map_label]
    width_blocks = sources.parse_map_constants(root)[0][const][1]
    blueprint = compositor.cut_trees(root, sources.load_blueprint(root, map_label), width_blocks, cut)
    return markers.cell_is_standable(root, map_label, tileset, width_blocks, cell, blueprint)


def _cell_land(root, map_label, cell):
    const, tileset = sources.parse_headers(root)[map_label]
    width_blocks = sources.parse_map_constants(root)[0][const][1]
    return markers.cell_is_land(root, map_label, tileset, width_blocks, cell)


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


def test_pewter_jigglypuff_scene_draws_the_whole_room(root):
    """Regression: restating the Poke Center's people as `sprites` lost the Cooltrainer F standing
    in front of the counter, so the scene takes its cast from the map and hand-places only the
    sleeping Pikachu, which the game does not put there."""
    spec = _trivia_spec("pewter-jigglypuff")
    grids = [s["grid"] for s in generators._screen_sprites(root, spec)]

    assert [3, 1] in grids, "Nurse Joy staffs the healing counter"
    assert [4, 1] in grids, "her Chansey stands beside her"
    assert [4, 3] in grids, "the Cooltrainer F waiting in front of the counter"
    assert [1, 3] in grids and [3, 3] in grids, "the Jigglypuff and sleeping Pikachu are kept"
    assert [s["sprite"] for s in spec["sprites"]] == ["SPRITE_PIKACHU"], "only the staged Pikachu"


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
INTERACTION_SPEC_FILES = ["trades.json", "hidden_items.json", "trainers.json", "overworld_items.json",
                          "gyms.json"]


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


def test_every_scene_stands_the_hero_on_a_tile_the_game_would_allow(root):
    """The strict version of the walkable check, over every spec file rather than the interaction
    ones: a cell counts only if its lower-left tile is open, the tile Gen 1 keys collision off.

    `cell_is_walkable` passes on any open sub-tile, which is why a hero can sit on a rock whose
    top half is sky and still look fine to a test. Regressions this catches: the Route 10 hero
    perched on the tree row below the Poke Center, the Snorlax shot standing in the bushes south
    of the fence, and the Articuno hero inside the rock wall under the chamber. A scene declaring
    `cut` is judged in the state it draws, and a hero out on the water says so with
    `player_sprite` (see the surf test below)."""
    for path in sorted(SPECS.glob("*.json")):
        for spec in json.loads(path.read_text()):
            if "map" not in spec or spec.get("player_sprite"):
                continue
            cells = [tuple(spec["player"])] if "player" in spec else []
            cells += [tuple(s["grid"]) for s in spec.get("sprites", []) if s.get("sprite") == "SPRITE_RED"]
            for cell in cells:
                assert _cell_standable(root, spec["map"], cell, spec.get("cut", ())), \
                    f"{spec['name']} ({path.name}): hero cell {cell} on {spec['map']} is not standable"


def test_interaction_scenes_never_stand_the_hero_on_another_object(root):
    """The other half of a legal hero tile: open floor is not enough if somebody already holds it.
    Regressions this catches: the Antidote hero on Viridian Forest's Youngster, the Lift Key hero
    on the B4F Rocket, the Nugget and Rare Candy heroes on the balls their captions point at."""
    for fname in INTERACTION_SPEC_FILES:
        for spec in json.loads((SPECS / fname).read_text()):
            taken = {tuple(o["grid"]): o["sprite_const"] for o
                     in sources.parse_object_events(root, spec["map"], include_battlers=True)}
            cells = [tuple(spec["player"])] if "player" in spec else []
            cells += [tuple(s["grid"]) for s in spec.get("sprites", []) if s.get("sprite") == "SPRITE_RED"]
            for cell in cells:
                assert cell not in taken, \
                    f"{spec['name']} ({fname}): hero cell {cell} is held by {taken.get(cell)}"


def test_an_object_the_game_starts_switched_off_stays_out_of_a_scene(root):
    """The default `show` opts out of, and the rule that correctly keeps Oak out of the Pallet Town
    exit shot: an object switched off at map load is not drawn."""
    balls = [o["grid"] for o in sources.parse_object_events(root, "RocketHideoutB4F", include_battlers=True)]

    assert (10, 2) not in balls, "the Lift Key ball is switched off at map load"
    assert (10, 12) in balls, "the HP Up ball on the same floor ships switched on"


def test_show_puts_a_switched_off_object_back_at_its_real_cell(root):
    """`show` pulls the object out of the game rather than restating it, so its cell, sprite and
    facing cannot drift from the disassembly the way a hand-placed sprite can."""
    spec = _item_spec("rocket-hideout-item-lift-key")
    drawn = {tuple(s["grid"]): s["file"] for s in generators._screen_sprites(root, spec)}

    assert drawn.get((10, 2)) == "poke_ball", "the shot telling you to grab the Lift Key shows it"
    assert (11, 2) in drawn, "the Rocket who dropped it is still standing there"


def test_show_and_hide_only_name_objects_that_move(root):
    """An entry matching nothing does nothing, and would read as a fix that quietly stopped
    working: `show` must name an object the map ships off, `hide` one it ships on."""
    for fname in INTERACTION_SPEC_FILES + ["step_shots.json", "encounters.json", "mew_glitch.json"]:
        for spec in json.loads((SPECS / fname).read_text()):
            if not (spec.get("show") or spec.get("hide")):
                continue
            const = sources.parse_headers(root)[spec["map"]][0]
            off = sources.parse_hidden_objects(root).get(const, set())
            on_map = {o["const"] for o in sources._object_events(root, spec["map"])}
            for name in spec.get("show", []):
                assert name in off, \
                    f"{spec['name']} ({fname}): show {name} is not switched off on {spec['map']}"
            for name in spec.get("hide", []):
                assert name in on_map - off, \
                    f"{spec['name']} ({fname}): hide {name} is not switched on on {spec['map']}"


def test_beating_giovanni_takes_him_off_the_floor_it_reveals_the_scope_on(root):
    """One script beat does both (HideObject GIOVANNI then ShowObject ITEM_4 in
    RocketHideoutB4F.asm), so no shot may claim the Silph Scope is there and Giovanni still is."""
    for name in ("rocket-hideout-item-silph-scope", "rocket-hideout-hidden-super-potion"):
        cells = [tuple(s["grid"]) for s in generators._screen_sprites(root, _item_spec(name))]

        assert (25, 3) not in cells, f"{name} still draws Giovanni after he leaves"

    scope = generators._screen_sprites(root, _item_spec("rocket-hideout-item-silph-scope"))

    assert {tuple(s["grid"]): s["file"] for s in scope}.get((25, 2)) == "poke_ball", \
        "the shot telling you to grab the Silph Scope shows it"


def test_a_handover_shot_stands_the_hero_face_to_face_with_the_giver(root):
    """An NPC hands something over across one tile, so a shot captioned with the pickup has to put
    the hero next to them and both of them looking at each other.

    The Captain is the one NPC in the game who does not turn around on his own: SSAnneCaptainsRoom
    sets BIT_NO_NPC_FACE_PLAYER on load, and MakeNPCFacePlayer's comment says that flag exists for
    exactly this scene. But the back-rub text clears it before the HM01 box prints, so by the frame
    this shot draws he has turned to face you, and his map facing of UP is the wrong one to use.
    Regression: the shot stood the hero two tiles below him, out of talking range."""
    spec = _step_shot("ss-anne-cut")
    captain = next(o for o in sources._object_events(root, "SSAnneCaptainsRoom")
                   if o["const"] == "SSANNECAPTAINSROOM_CAPTAIN")
    (px, py), (cx, cy) = spec["player"], captain["grid"]
    drawn = {tuple(s["grid"]): s["frame"] for s in generators._screen_sprites(root, spec)}

    assert abs(px - cx) + abs(py - cy) == 1, "the hero has to be within talking range"
    assert spec["player_dir"] == "UP" and py > cy, "looking up at him"
    assert drawn[(cx, cy)] == compositor.DIR_TO_FRAME["DOWN"][0], "and the Captain looking back"
    assert len(drawn) == 2, "the hero and the Captain, nobody drawn twice"
    assert _cell_standable(root, "SSAnneCaptainsRoom", (px, py)), "on a tile of the cabin floor"


def test_the_ship_rival_meets_you_where_the_script_stops_him(root):
    """SSAnne2F triggers on the player standing at [36, 8] or [37, 8], then walks the rival down
    from his spawn: three steps for the left tile, four for the right. So from [36, 8] he ends one
    tile up at [36, 7], and SSAnne2FSetFacingDirectionScript turns him DOWN onto you.

    Regression: the shot stood the hero at [36, 6], two tiles above any trigger, and drew the rival
    still parked on his spawn cell three tiles further up, with a spotted-trainer '!' that this
    scene never shows (nothing here calls the emote; the rival is walked in by script)."""
    spec = _trainer_spec("ss-anne-rival")
    # raw objects: the rival ships switched off and is only ShowObject'd once you trip the trigger
    rival = next(o for o in sources._object_events(root, "SSAnne2F")
                 if o["const"] == "SSANNE2F_RIVAL")
    hero, blue = tuple(spec["player"]), tuple(spec["sprites"][0]["grid"])

    assert hero == (36, 8), "the hero stands on a tile the script actually triggers on"
    assert blue == (rival["grid"][0], hero[1] - 1), "the rival stops one tile short of you"
    assert spec["player_dir"] == "UP" and spec["sprites"][0]["dir"] == "DOWN", "facing each other"
    assert not any(s.get("emote") for s in spec["sprites"]), "no '!' in a scripted walk-up"
    assert _cell_standable(root, "SSAnne2F", hero) and _cell_standable(root, "SSAnne2F", blue)


def test_the_ship_cabin_item_shots_frame_a_ball_in_the_right_cabin(root):
    """The ship's six item balls live in cabins that share three composite `Rooms` maps, laid out
    on a 3x2 grid ten cells apart. A focus off by one cabin still renders a plausible room, so each
    shot has to sit on a cell the game really puts a ball on, with the hero next to it."""
    shots = [s for s in json.loads((SPECS / "overworld_items.json").read_text())
             if s["name"].startswith("ss-anne-item-")]

    assert len(shots) == 6, "one shot per item ball aboard the S.S. Anne"
    for spec in shots:
        balls = {tuple(o["grid"]) for o
                 in sources.parse_object_events(root, spec["map"], include_battlers=True)
                 if o["sprite_const"] == "SPRITE_POKE_BALL"}
        focus, (px, py) = tuple(spec["focus"]), spec["player"]

        assert focus in balls, f"{spec['name']}: {spec['map']} has no item ball at {focus}"
        assert abs(px - focus[0]) + abs(py - focus[1]) == 1, \
            f"{spec['name']}: hero at {spec['player']} is not beside the ball at {focus}"


def test_a_found_item_shot_marks_a_cell_the_game_really_hides_that_item_on(root):
    """The other half of a found-item frame: the box names an item, so the marked cell has to be a
    HiddenItems event on that map handing over exactly that item. Catches a shot pointed at the
    wrong bin, bed or rock, which renders fine and quietly teaches the reader a dead tile."""
    hidden = {(const, x, y): item for const, x, y, item in sources.parse_hidden_events(root)}
    for fname in INTERACTION_SPEC_FILES:
        for spec in json.loads((SPECS / fname).read_text()):
            if spec.get("type") != "dialog" or "found_item" not in spec.get("dialog", {}):
                continue
            const = sources.parse_headers(root)[spec["map"]][0]
            item = hidden.get((const, *spec["marker"]))

            assert item, f"{spec['name']} ({fname}): {spec['map']} hides nothing at {spec['marker']}"
            assert sources.item_display_name(item).upper() == spec["dialog"]["found_item"], \
                f"{spec['name']} ({fname}): {spec['map']} hides {item} at {spec['marker']}"


def test_a_hero_out_on_the_water_is_drawn_on_the_surf_sprite(root):
    """Gen 1 swaps the player onto SPRITE_SEEL the moment they step off dry land, so a scene whose
    `player` cell is water has to say so with `player_sprite` or it draws someone standing on the
    sea. Vermilion's Max Ether is the case that forces it: the only tile you can face the item
    from is open water, so the shot of taking it is a shot of surfing."""
    for fname in INTERACTION_SPEC_FILES:
        for spec in json.loads((SPECS / fname).read_text()):
            if "player" not in spec:
                continue
            cell = tuple(spec["player"])
            afloat = (_cell_walkable(root, spec["map"], cell)
                      and not _cell_land(root, spec["map"], cell))
            if not afloat:
                continue

            assert spec.get("player_sprite"), \
                f"{spec['name']} ({fname}): hero at {cell} is on water with no surf sprite"

    ether = _item_spec("vermilion-city-hidden-max-ether")
    drawn = {tuple(s["grid"]): s["file"] for s in generators._screen_sprites(root, ether)}

    assert drawn[tuple(ether["player"])] == sources.parse_sprite_table(root)["SPRITE_SEEL"]
    assert not _cell_land(root, "VermilionCity", tuple(ether["player"])), "the hero is afloat"


def test_a_found_item_shot_stands_the_hero_within_reach_of_what_it_marks(root):
    """A "<PLAYER> found X!" frame claims the pickup just happened, so the hero has to be on a tile
    the game would let them press A from: orthogonally adjacent to the marked cell.

    Regression: Vermilion's Max Ether sits at [14, 11] with water on its only open side, and the
    shot stood the hero three tiles south at [14, 14] with two building blocks in between. A spot
    you cannot reach without Surf cannot carry a found-item box, so that one is a plain screen with
    a marker instead, and this test is what keeps the two kinds honest."""
    for fname in INTERACTION_SPEC_FILES:
        for spec in json.loads((SPECS / fname).read_text()):
            if spec.get("type") != "dialog" or "found_item" not in spec.get("dialog", {}):
                continue
            marker = spec.get("marker")
            assert marker, f"{spec['name']} ({fname}): a found-item shot marks the cell it found"
            (px, py), (mx, my) = spec["player"], marker

            assert abs(px - mx) + abs(py - my) == 1, \
                f"{spec['name']} ({fname}): hero at {spec['player']} cannot press A on {marker}"


def test_route_25_tm_guard_stands_where_the_walkthrough_leaves_him(root):
    """Route 25's Jr. Trainer spawns on the one gap into the TM19 pocket, and the step tells you to
    trigger him from the far end of his line of sight so he walks down clear of it: he stops one
    tile short of you (TrainerWalkUpToPlayer), which is sight - 1 cells below his post, freeing both
    the gap and the cell you reach it through. Triggering closer parks him on that cell instead, so
    a shot that still draws him on or beside the gap contradicts the instruction beside it."""
    spec = _item_spec("route-25-item-tm-seismic-toss")
    guard = next(o for o in sources._object_events(root, "Route25")
                 if o["const"] == "ROUTE25_COOLTRAINER_M")
    sight = sources.parse_trainer_sight(root, "Route25")[guard["text_const"]]
    gap_x, gap_y = guard["grid"]
    drawn = {tuple(s["grid"]): s["file"] for s in generators._screen_sprites(root, spec)}

    assert sight > 1, "a guard who only engages point-blank could never be walked off the gap"
    assert not any(_cell_standable(root, "Route25", c)
                   for c in ((gap_x - 1, gap_y), (gap_x + 1, gap_y))), \
        "the gap has a second approach, so which cell the guard ends on would not matter"
    assert (gap_x, gap_y) not in drawn, "the shot still plugs the gap it tells you to clear"
    assert (gap_x, gap_y + 1) not in drawn, "the cell you reach the gap through must be clear too"
    assert drawn.get((gap_x, gap_y + sight - 1)) == \
        sources.parse_sprite_table(root)[guard["sprite_const"]], \
        "the guard is not standing where triggering him from the far end of his sight leaves him"


def test_a_later_scene_on_the_same_floor_leaves_a_collected_ball_taken(root):
    """The judgement no field expresses: the walkthrough sends you past these two after the Lift Key
    and Silph Scope steps, and the Super Potion shot stands the hero on the Scope's own cell."""
    for name in ("rocket-hideout-item-tm-razor-wind", "rocket-hideout-hidden-super-potion"):
        spec = _item_spec(name)
        drawn = {tuple(s["grid"]): s["file"] for s in generators._screen_sprites(root, spec)}

        assert not spec.get("show"), f"{name} is set after those balls are picked up"
        assert "poke_ball" not in (drawn.get((10, 2)), drawn.get((25, 2))), \
            f"{name} draws a ball the walkthrough already had you collect"


def test_viridian_forest_antidote_hero_stands_beside_the_youngster(root):
    """Regression: this shot stood the hero on [16, 43], the Youngster's own cell, so the NPC
    vanished under the hero. The tree is walled in on three sides, leaving its west cell."""
    spec = _item_spec("viridian-forest-hidden-antidote")
    hero, item = tuple(spec["player"]), tuple(spec["marker"])
    youngster = next(o for o in sources.parse_object_events(root, "ViridianForest")
                     if o["grid"] == (16, 43))

    assert hero != youngster["grid"], "the Youngster keeps the cell south of the tree"
    assert (item[0] - hero[0], item[1] - hero[1]) == (1, 0), "one tile west of the Antidote tile"
    assert spec["player_dir"] == "RIGHT", "facing east into the tree"
    assert youngster["grid"] in [tuple(s["grid"]) for s in generators._screen_sprites(root, spec)], \
        "the shot still draws the Youngster the game puts there"


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


def test_oaks_lab_poke_balls_scene_trails_pikachu(root, pikachu_follower):
    # Returning to Oak for the five free Poke Balls happens after Pikachu is caught, so it walks
    # behind the hero. The hero stands at [5, 3] facing up, so Pikachu trails one tile south.
    spec = _step_shot("oaks-lab-poke-balls")
    trailing = generators._follower(root, spec, spec["player"], spec.get("player_dir", "DOWN"),
                                    generators._screen_sprites(root, spec))
    assert trailing is not None, "the scene must not opt out of the Pikachu follower"
    assert trailing["file"] == "pikachu" and trailing["grid"] == [5, 4]


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


def test_the_gym_puzzle_shot_stands_at_a_real_trash_can(root):
    """The Vermilion switch shot has to face a can the game actually scripts. The gym floor is
    open on every side of every can, so a hero one tile off still renders happily, pointing at
    nothing: only the hidden-event list says which tiles are cans."""
    spec = _gym_spec("vermilion-gym-second-switch")
    cans = _trash_can_cells(root)
    x, y = spec["player"]
    faced = {"UP": (x, y - 1), "DOWN": (x, y + 1),
             "LEFT": (x - 1, y), "RIGHT": (x + 1, y)}[spec["player_dir"]]

    assert len(cans) == 15, "the puzzle is 15 cans"
    assert faced in cans, f"the hero faces {faced}, which is not one of the gym's trash cans"


def test_the_gym_puzzle_shot_quotes_the_games_own_second_switch_line(root):
    """The caption is the game's text, not ours: `_VermilionGymTrashSuccessText3` is what prints
    when the second switch is the right one, which is the beat the shot illustrates."""
    spec = _gym_spec("vermilion-gym-second-switch")
    text = (pathlib.Path(root) / "data/text/text_2.asm").read_text()
    block = re.search(r"_VermilionGymTrashSuccessText3::(.*?)text_end", text, re.S).group(1)
    quoted = re.findall(r'"([^"]*)"', block)

    for line in spec["dialog"]["lines"]:
        assert line in quoted, f"{line!r} is not a line of _VermilionGymTrashSuccessText3"
