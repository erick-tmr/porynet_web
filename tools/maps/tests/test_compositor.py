import compositor


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
