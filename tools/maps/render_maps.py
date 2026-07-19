#!/usr/bin/env python3
"""Render full Pokemon Yellow area maps to RGB PNGs from the pret/pokeyellow source.

A map is a grid of blocks; each block is 4x4 tiles (32x32 px); each tile is an 8x8
graphic in the tileset. Coloring follows the game's SetPal_Overworld: every map uses a
single 4-colour super-palette (city -> its own, route -> PAL_ROUTE, cavern tileset ->
PAL_CAVE, cemetery tileset -> PAL_GRAYMON, interior -> its parent town/route).

Reads (relative to the pokeyellow root):
  constants/map_constants.asm      map_const NAME, WIDTH, HEIGHT  (blocks; WIDTH first)
  data/maps/headers/<Map>.asm      map_header Label, CONST, TILESET, connections
  gfx/tilesets/<tileset>.png       2-bit grayscale grid of 8x8 tiles (shades 0/85/170/255)
  gfx/blocksets/<tileset>.bst      16 bytes/block = 4x4 tile indices
  maps/<Label>.blk                 WIDTH*HEIGHT bytes, one block index per block
  data/sgb/sgb_palettes.asm        SuperPalettes: RGB c0, c1, c2, c3 per PAL_* id
"""
import re
import pathlib
from functools import lru_cache
from PIL import Image

BLOCK_TILES = 4          # tiles per block side
TILE_PX = 8
BLOCK_PX = BLOCK_TILES * TILE_PX   # 32

# PAL_* ids used by SetPal_Overworld (constants/palette_constants.asm)
PAL_ROUTE = 0
PAL_GRAYMON = 0x19
PAL_CAVE = 0x23


def _rgb5_to_8(v):
    return (v << 3) | (v >> 2)


@lru_cache(maxsize=None)
def _root(path_str):
    return pathlib.Path(path_str)


def parse_map_constants(root):
    """Return ({const: (index, width, height)}, num_city_maps, first_indoor_map)."""
    dims, idx = {}, 0
    num_city = first_indoor = None
    for line in (root / "constants/map_constants.asm").read_text().splitlines():
        m = re.match(r"\s*map_const\s+(\w+)\s*,\s*(\d+)\s*,\s*(\d+)", line)
        if m:
            dims[m.group(1)] = (idx, int(m.group(2)), int(m.group(3)))
            idx += 1
            continue
        if re.match(r"\s*DEF\s+NUM_CITY_MAPS\s+EQU\s+const_value", line):
            num_city = idx
        elif re.match(r"\s*DEF\s+FIRST_INDOOR_MAP\s+EQU\s+const_value", line):
            first_indoor = idx
    return dims, num_city, first_indoor


def parse_headers(root):
    """Return {label: (const, tileset)} for every map header."""
    out = {}
    for path in sorted((root / "data/maps/headers").glob("*.asm")):
        for line in path.read_text().splitlines():
            m = re.match(r"\s*map_header\s+(\w+)\s*,\s*(\w+)\s*,\s*(\w+)", line)
            if m:
                out[m.group(1)] = (m.group(2), m.group(3))
    return out


def _snake_to_camel(name):
    return "".join(part.capitalize() for part in name.split("_"))


@lru_cache(maxsize=None)
def parse_tileset_files(root_str):
    """Map tileset name (CamelCase) -> its shared gfx/blockset basename via gfx/tilesets.asm.
    Some tilesets (RedsHouse1/RedsHouse2, ...) share one file, so the const does not lowercase
    straight to a filename."""
    mapping, pending = {}, []
    for line in (_root(root_str) / "gfx/tilesets.asm").read_text().splitlines():
        m = re.match(r"\s*(\w+)_GFX::", line)
        if m:
            pending.append(m.group(1))
        inc = re.search(r'INCBIN\s+"gfx/tilesets/([\w-]+)\.2bpp"', line)
        if inc and pending:
            for name in pending:
                mapping[name] = inc.group(1)
            pending = []
    return mapping


def tileset_basename(root_str, tileset_const):
    return parse_tileset_files(root_str).get(_snake_to_camel(tileset_const), tileset_const.lower())


def parse_super_palettes(root):
    """Return [ [ (r,g,b)*4 ], ... ] indexed by PAL_* id."""
    text = (root / "data/sgb/sgb_palettes.asm").read_text().splitlines()
    pals, collecting = [], False
    for line in text:
        if re.match(r"^SuperPalettes:", line):
            collecting = True
            continue
        if collecting:
            if re.match(r"^\w+:", line):          # next label ends the table
                break
            m = re.match(r"\s*RGB\s+(.+?)(?:;.*)?$", line)
            if not m:
                continue
            nums = [int(n) for n in re.findall(r"\d+", m.group(1))]
            if len(nums) >= 12:
                colors = [tuple(_rgb5_to_8(nums[i + c]) for c in range(3))
                          for i in range(0, 12, 3)]
                pals.append(colors)
    return pals


@lru_cache(maxsize=None)
def load_tiles(root_str, tileset):
    """Return a list of 8x8 'L'-mode tiles from gfx/tilesets/<tileset>.png (row-major)."""
    png = Image.open(_root(root_str) / f"gfx/tilesets/{tileset}.png").convert("L")
    cols = png.width // TILE_PX
    rows = png.height // TILE_PX
    tiles = []
    for ty in range(rows):
        for tx in range(cols):
            tiles.append(png.crop((tx * TILE_PX, ty * TILE_PX,
                                   tx * TILE_PX + TILE_PX, ty * TILE_PX + TILE_PX)))
    return tiles


@lru_cache(maxsize=None)
def load_blockset(root_str, tileset):
    """Return a list of blocks; each block is 16 tile indices (4x4 row-major)."""
    data = (_root(root_str) / f"gfx/blocksets/{tileset}.bst").read_bytes()
    return [list(data[i:i + 16]) for i in range(0, len(data), 16)]


def resolve_palette_id(const, tileset, dims, num_city, first_indoor, parent_const):
    """Mirror SetPal_Overworld: pick the map's super-palette id."""
    if tileset == "CEMETERY":
        return PAL_GRAYMON
    if tileset == "CAVERN":
        return PAL_CAVE
    idx = dims[const][0]
    if idx >= first_indoor and parent_const and parent_const in dims:
        idx = dims[parent_const][0]           # interiors inherit their town/route
    if idx < num_city:
        return idx + 1                        # a town's palette id is its map id + 1
    return PAL_ROUTE


def render_map(root_str, label, parent_const=None):
    """Render one pokeyellow map (by header label, e.g. 'PalletTown') to an RGB image."""
    root = _root(root_str)
    dims, num_city, first_indoor = parse_map_constants(root)
    headers = parse_headers(root)
    if label not in headers:
        raise KeyError(f"no map header for {label}")
    const, tileset = headers[label]
    tileset_file = tileset_basename(root_str, tileset)
    _, w, h = dims[const]

    tiles = load_tiles(root_str, tileset_file)
    blocks = load_blockset(root_str, tileset_file)
    blk = (root / f"maps/{label}.blk").read_bytes()

    pals = parse_super_palettes(root)
    pal_id = resolve_palette_id(const, tileset, dims, num_city, first_indoor, parent_const)
    colors = pals[pal_id]                     # 4 RGB tuples, index 0 = lightest

    # shade lookup: PNG 255 -> palette 0 (lightest) ... PNG 0 -> palette 3 (darkest)
    shade_to_rgb = {255: colors[0], 170: colors[1], 85: colors[2], 0: colors[3]}
    tile_cache = {}

    def colored_tile(tile_idx):
        if tile_idx not in tile_cache:
            gray = tiles[tile_idx] if tile_idx < len(tiles) else tiles[0]
            rgb = Image.new("RGB", (TILE_PX, TILE_PX))
            rgb.putdata([shade_to_rgb.get(px, colors[0]) for px in gray.getdata()])
            tile_cache[tile_idx] = rgb
        return tile_cache[tile_idx]

    canvas = Image.new("RGB", (w * BLOCK_PX, h * BLOCK_PX))
    for by in range(h):
        for bx in range(w):
            block_id = blk[by * w + bx]
            block = blocks[block_id] if block_id < len(blocks) else blocks[0]
            for ty in range(BLOCK_TILES):
                for tx in range(BLOCK_TILES):
                    tile_idx = block[ty * BLOCK_TILES + tx]
                    canvas.paste(colored_tile(tile_idx),
                                 (bx * BLOCK_PX + tx * TILE_PX,
                                  by * BLOCK_PX + ty * TILE_PX))
    return canvas


if __name__ == "__main__":
    import sys
    root = sys.argv[1]
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else pathlib.Path(".")
    out.mkdir(parents=True, exist_ok=True)
    for spec in sys.argv[3:]:
        label, _, parent = spec.partition(":")
        img = render_map(root, label, parent or None)
        img.save(out / f"{label}.png")
        print(f"{label}: {img.width}x{img.height}")
