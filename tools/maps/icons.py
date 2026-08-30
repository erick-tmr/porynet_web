from PIL import Image

import compositor
import sources

CELL_TILES = 2

GRASS_ICON = "tall-grass"
BOULDER_ICON = "boulder"

# The Strength boulder, drawn on its own so the app can put one over a step's map where the game
# has not put one yet. Every boulder below Seafoam 1F is shipped hidden and revealed when the one
# above it falls, so a floor drawn as the game loads it has bare rock where the step says to shove
# something; baking them into the map instead would have the overview claiming boulders that are
# not there. The cave palette, because that is the only kind of floor one is ever drawn on.
BOULDER_SPRITE = "boulder"


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


def boulder_sprite(root_str):
    """One boulder, palettised the way the map compositor palettes a sprite, on transparency.

    Same shading as `compositor.overlay_sprites`: the sheet's four values are the object palette
    read through the map's own colors, and only the corners are see-through, so a boulder drawn by
    the app sits on the floor exactly as a baked one would."""
    sheet = sources.load_sprite_sheet(root_str, BOULDER_SPRITE)
    colors = compositor._map_colors(root_str, sources.PAL_CAVE)
    shade = {255: None, 170: colors[0], 85: colors[1], 0: colors[3]}
    icon = Image.new("RGBA", (sources.UNIT_PX, sources.UNIT_PX))
    icon.putdata([(0, 0, 0, 0) if shade.get(p) is None else (*shade[p], 255)
                  for p in sheet.crop((0, 0, sources.UNIT_PX, sources.UNIT_PX)).getdata()])
    return icon


def render_icons(root_str):
    return {GRASS_ICON: grass_swatch(root_str), BOULDER_ICON: boulder_sprite(root_str)}
