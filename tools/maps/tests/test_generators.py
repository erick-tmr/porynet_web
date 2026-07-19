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
    assert {n["file"] for n in npcs} == {"oak", "girl", "fisher"}


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


def test_unknown_type_raises(root):
    with pytest.raises(ValueError):
        generators.generate(root, {"type": "bogus", "name": "x"})
