import pytest

import compositor
import sources


def test_dir_to_frame():
    assert compositor.DIR_TO_FRAME["DOWN"] == (0, False)
    assert compositor.DIR_TO_FRAME["UP"] == (1, False)
    assert compositor.DIR_TO_FRAME["LEFT"] == (2, False)
    assert compositor.DIR_TO_FRAME["RIGHT"] == (2, True)     # right = left, flipped


def test_shade_to_ramp():
    ramp = [(0, 0, 0), (1, 1, 1), (2, 2, 2), (3, 3, 3)]
    assert compositor._shade_to_ramp(255, ramp) == (0, 0, 0)   # lightest
    assert compositor._shade_to_ramp(170, ramp) == (1, 1, 1)
    assert compositor._shade_to_ramp(85, ramp) == (2, 2, 2)
    assert compositor._shade_to_ramp(0, ramp) == (3, 3, 3)     # darkest


def test_render_map_dimensions(root):
    image, colors = compositor.render_map(root, "PalletTown")
    assert image.size == (320, 288)            # 10x9 blocks * 32px
    assert len(colors) == 4


def test_render_map_stops_at_the_blueprint_not_the_header(root):
    image, _colors = compositor.render_map(root, "UndergroundPathNorthSouth")
    assert image.size == (128, 736)            # 4x23 blocks * 32px, not the header's 4x24


def test_render_battle_dimensions(root):
    assert compositor.render_battle(root, "BROCK").size == compositor.SCREEN == (160, 144)


def test_render_screen_dimensions(root):
    image, _ = compositor.render_screen(root, "ViridianForest", [16, 42])
    assert image.size == (160, 144)


def test_palette_modes(root):
    original = compositor.PALETTE_MODE
    try:
        compositor.PALETTE_MODE = "gbc"
        gbc = compositor._map_colors(root, 1)
        compositor.PALETTE_MODE = "sgb"
        sgb = compositor._map_colors(root, 1)
        compositor.PALETTE_MODE = "dmg"
        dmg = compositor._map_colors(root, 1)
        assert len(gbc) == len(sgb) == len(dmg) == 4
        assert gbc != sgb                                   # GBC is more saturated than SGB
        assert dmg == compositor.DMG_PALETTE                # DMG is the fixed greens...
        assert compositor._map_colors(root, 7) == compositor.DMG_PALETTE   # ...ignoring pal id
    finally:
        compositor.PALETTE_MODE = original


def test_grass_cells_only_exist_where_the_tileset_has_grass(root):
    assert len(compositor.grass_cells(root, "ViridianForest")) == 137
    assert compositor.grass_cells(root, "MtMoon1F") == frozenset()


def test_a_sprite_standing_in_grass_is_covered_from_the_waist_down(root):
    """The game drops the lower half of the sprite behind the background, so the blades hide the
    legs. The top half must be untouched."""
    cell = (2, 18)
    grass = compositor.grass_cells(root, "ViridianForest")
    assert cell in grass

    canvas, colors = compositor.render_map(root, "ViridianForest")
    sprite = [{"file": "youngster", "frame": 0, "grid": list(cell), "flip": False}]
    plain = compositor.overlay_sprites(canvas.copy(), root, sprite, colors)
    blended = compositor.overlay_sprites(canvas.copy(), root, sprite, colors, grass)

    left, top = cell[0] * 16, cell[1] * 16
    head = (left, top, left + 16, top + 8)
    legs = (left, top + 8, left + 16, top + 16)

    assert plain.crop(head).tobytes() == blended.crop(head).tobytes()
    assert plain.crop(legs).tobytes() != blended.crop(legs).tobytes()


def test_a_sprite_off_the_grass_is_drawn_whole(root):
    canvas, colors = compositor.render_map(root, "ViridianForest")
    grass = compositor.grass_cells(root, "ViridianForest")
    cell = (16, 43)   # the forest's south-entrance NPC, standing on a path
    assert cell not in grass

    sprite = [{"file": "youngster", "frame": 0, "grid": list(cell), "flip": False}]
    plain = compositor.overlay_sprites(canvas.copy(), root, sprite, colors)
    blended = compositor.overlay_sprites(canvas.copy(), root, sprite, colors, grass)

    assert plain.tobytes() == blended.tobytes()


def test_cutting_a_tree_swaps_the_block_the_game_swaps(root):
    """One cell names one tree, but Gen 1 replaces the whole 32px block around it, so the cut has
    to be applied at block resolution or the felled tile would not line up with the game's."""
    width = sources.parse_map_constants(root)[0]["VIRIDIAN_CITY"][1]
    blueprint = sources.load_blueprint(root, "ViridianCity")
    index = (22 // 2) * width + (8 // 2)
    assert blueprint[index] == 0x34, "the Fisher's plot is walled by block $34"

    cut = compositor.cut_trees(root, blueprint, width, [(8, 22)])

    assert cut[index] == 0x6F
    assert list(blueprint) == list(sources.load_blueprint(root, "ViridianCity")), \
        "the cached blueprint is untouched"
    assert cut[:index] == list(blueprint[:index]), "no other block moves"


def test_cutting_a_cell_that_holds_no_cuttable_tree_raises(root):
    """A spec pointing at plain ground is an authoring mistake: the shot would silently draw the
    same picture as one with no `cut` at all."""
    width = sources.parse_map_constants(root)[0]["VIRIDIAN_CITY"][1]
    blueprint = sources.load_blueprint(root, "ViridianCity")

    with pytest.raises(ValueError, match="no cuttable tree"):
        compositor.cut_trees(root, blueprint, width, [(7, 23)])


def test_a_map_with_nothing_cut_is_the_map_the_game_ships(root):
    plain, _ = compositor.render_map(root, "ViridianCity")
    cut, _ = compositor.render_map(root, "ViridianCity", None, [(8, 22)])

    assert plain.size == cut.size
    assert plain.tobytes() != cut.tobytes(), "felling the tree changes the picture"
