from PIL import Image

import compositor
import sources

CELL_TILES = 2

GRASS_ICON = "tall-grass"


def grass_swatch(root_str, tileset_const="OVERWORLD", pal_id=sources.PAL_ROUTE):
    tile_id = sources.grass_tile(root_str, tileset_const)
    if tile_id is None:
        raise KeyError(f"{tileset_const} has no grass tile")

    tiles = sources.load_tiles(root_str, sources.tileset_basename(root_str, tileset_const))
    colors = compositor._map_colors(root_str, pal_id)
    shade_to_rgb = {255: colors[0], 170: colors[1], 85: colors[2], 0: colors[3]}

    tile = Image.new("RGB", (sources.TILE_PX, sources.TILE_PX))
    tile.putdata([shade_to_rgb.get(px, colors[0]) for px in tiles[tile_id].getdata()])

    cell = Image.new("RGB", (sources.TILE_PX * CELL_TILES,) * 2)
    for ty in range(CELL_TILES):
        for tx in range(CELL_TILES):
            cell.paste(tile, (tx * sources.TILE_PX, ty * sources.TILE_PX))
    return cell


def render_icons(root_str):
    return {GRASS_ICON: grass_swatch(root_str)}
