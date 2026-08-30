import pytest

import compositor
import icons
import sources


def test_grass_swatch_is_one_movement_cell(root):
    cell = icons.grass_swatch(root)

    assert cell.size == (16, 16)
    assert cell.mode == "RGB"


def test_grass_swatch_tiles_one_tile_four_times(root):
    cell = icons.grass_swatch(root)
    quads = {cell.crop((x, y, x + 8, y + 8)).tobytes()
             for y in (0, 8) for x in (0, 8)}

    assert len(quads) == 1, "every quarter of the cell is the same grass tile"


def test_grass_swatch_draws_the_tile_the_game_calls_grass(root):
    assert sources.grass_tile(root, "OVERWORLD") == 0x52

    tiles = sources.load_tiles(root, sources.tileset_basename(root, "OVERWORLD"))
    colors = compositor._map_colors(root, sources.PAL_ROUTE)
    shade = {255: colors[0], 170: colors[1], 85: colors[2], 0: colors[3]}
    expected = [shade[px] for px in tiles[0x52].getdata()]

    assert list(icons.grass_swatch(root).crop((0, 0, 8, 8)).getdata()) == expected


def test_grass_swatch_wears_the_route_palette_not_a_town_one(root):
    route = icons.grass_swatch(root)
    pallet = icons.grass_swatch(root, pal_id=1)

    assert route.tobytes() != pallet.tobytes()
    assert compositor._map_colors(root, sources.PAL_ROUTE)[1] == (132, 255, 33)


def test_grass_swatch_refuses_a_tileset_with_no_grass(root):
    with pytest.raises(KeyError, match="CAVERN"):
        icons.grass_swatch(root, tileset_const="CAVERN")


def test_forest_has_its_own_grass_tile(root):
    assert sources.grass_tile(root, "FOREST") == 0x20
    assert icons.grass_swatch(root, tileset_const="FOREST").size == (16, 16)


def test_render_icons_names_every_icon_it_cuts(root):
    rendered = icons.render_icons(root)

    assert set(rendered) == {icons.GRASS_ICON, icons.BOULDER_ICON}
    assert rendered[icons.GRASS_ICON].size == (16, 16)
    assert rendered[icons.BOULDER_ICON].size == (16, 16)


def test_the_boulder_is_cut_on_transparency_so_it_sits_on_the_floor(root):
    """The app draws it over a step's map, where anything but a see-through corner would print a
    square of cave over the cave. Same shading `compositor.overlay_sprites` gives a baked one, so
    the two are the same boulder."""
    boulder = icons.boulder_sprite(root)
    colors = compositor._map_colors(root, sources.PAL_CAVE)

    assert boulder.mode == "RGBA"
    assert boulder.getpixel((0, 0)) == (0, 0, 0, 0), "the corners are the sheet's own 255"
    assert (*colors[3], 255) in set(boulder.getdata()), "and its outline is the map's dark colour"


def test_grass_icon_is_deterministic(root):
    assert icons.grass_swatch(root).tobytes() == icons.grass_swatch(root).tobytes()
