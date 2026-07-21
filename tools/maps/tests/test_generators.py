import pytest

import generators


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


def test_unknown_type_raises(root):
    with pytest.raises(ValueError):
        generators.generate(root, {"type": "bogus", "name": "x"})
