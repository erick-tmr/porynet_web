#!/usr/bin/env python3
"""Compose Pokemon Yellow images from the parsed sources.

Two bases:
  - render_map: a colored overworld map (grid of 32x32 blocks), the input for area maps and
    every annotated/NPC/dialog scene.
  - render_battle: the pre-battle face-off frame on the native 160x144 screen.

Plus overlays that go on top of a map: overworld sprites (NPCs / the player), directional
pointer arrows, and (via text.py) a bottom dialog box.
"""
from PIL import Image, ImageDraw

import sources
import text

TILE_PX = sources.TILE_PX          # 8
BLOCK_PX = sources.BLOCK_PX        # 32
UNIT_PX = sources.UNIT_PX          # 16 (overworld movement cell + sprite footprint)
SCREEN = (160, 144)                # native Game Boy screen

ARROW_FILL = (248, 192, 32)        # amber pointer, matches the design system's --amber
ARROW_OUTLINE = (23, 22, 34)       # the design system's near-black ink (#171622)

# overworld facing (object_event direction / sprite dir) -> (frame index, horizontal flip)
DIR_TO_FRAME = {
    "DOWN": (0, False), "UP": (1, False), "LEFT": (2, False), "RIGHT": (2, True),
}


def _shade_to_ramp(value, ramp):
    """Map a 2-bit grayscale value (0/85/170/255) to a 4-color ramp index (lightest first)."""
    return ramp[min(3, round((255 - value) / 85))]


# --- map ---------------------------------------------------------------------

def render_map(root_str, label, parent_const=None):
    """Render one pokeyellow map (by header label) to (RGB image, palette colors)."""
    headers = sources.parse_headers(root_str)
    if label not in headers:
        raise KeyError(f"no map header for {label}")
    const, tileset = headers[label]
    tileset_file = sources.tileset_basename(root_str, tileset)
    dims, _, _ = sources.parse_map_constants(root_str)
    _, w, h = dims[const]

    tiles = sources.load_tiles(root_str, tileset_file)
    blocks = sources.load_blockset(root_str, tileset_file)
    blk = sources.load_blueprint(root_str, label)

    pal_id = sources.resolve_palette_id(root_str, const, tileset, parent_const)
    colors = sources.parse_super_palettes(root_str)[pal_id]   # 4 RGB tuples, index 0 = lightest
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
            block = blocks[blk[by * w + bx]] if blk[by * w + bx] < len(blocks) else blocks[0]
            for ty in range(sources.BLOCK_TILES):
                for tx in range(sources.BLOCK_TILES):
                    canvas.paste(colored_tile(block[ty * sources.BLOCK_TILES + tx]),
                                 (bx * BLOCK_PX + tx * TILE_PX, by * BLOCK_PX + ty * TILE_PX))
    return canvas, colors


# --- overlays ----------------------------------------------------------------

def overlay_sprites(canvas, root_str, sprites, colors):
    """Composite 16x16 overworld sprite frames onto a map, colored in the map's palette.

    Each sprite: {file, frame, grid:[gx,gy], flip?}. The sprite's white (255) pixels are
    transparent; grid is the 16px movement cell, so pixel top-left = grid*16."""
    out = canvas.convert("RGBA")
    shade = {255: None, 170: colors[1], 85: colors[2], 0: colors[3]}
    for spr in sprites:
        sheet = Image.open(sources._root(root_str) / f"gfx/sprites/{spr['file']}.png").convert("L")
        tile = sheet.crop((0, spr["frame"] * 16, 16, spr["frame"] * 16 + 16))
        if spr.get("flip"):
            tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
        rgba = Image.new("RGBA", (16, 16))
        rgba.putdata([(0, 0, 0, 0) if shade.get(p) is None else (*shade[p], 255) for p in tile.getdata()])
        out.alpha_composite(rgba, (spr["grid"][0] * UNIT_PX, spr["grid"][1] * UNIT_PX))
    return out.convert("RGB")


def _rotate90(points, direction):
    """Rotate points about the origin by 0/90/180/270 deg so an up-arrow can face any way."""
    for _ in range({"up": 0, "right": 1, "down": 2, "left": 3}[direction]):
        points = [(-y, x) for x, y in points]
    return points


def overlay_arrows(canvas, arrows):
    """Draw directional pointer arrows (map annotations, not game art).

    Each arrow: {dir: up|down|left|right, grid:[gx,gy] | px:[cx,cy], size?:[w,h]}. `grid` uses
    the 16px cell (center px = grid*16+8); `px` gives the center directly."""
    draw = ImageDraw.Draw(canvas)
    for a in arrows:
        if "grid" in a:
            cx, cy = a["grid"][0] * UNIT_PX + UNIT_PX // 2, a["grid"][1] * UNIT_PX + UNIT_PX // 2
        else:
            cx, cy = a["px"]
        w, h = a.get("size", (16, 26))
        hw, sw, hh = w // 2, max(2, w // 3), h // 2
        head = _rotate90([(0, -h // 2), (-hw, -h // 2 + hh), (hw, -h // 2 + hh)], a["dir"])
        shaft = _rotate90([(-sw, -h // 2 + hh), (sw, -h // 2 + hh), (sw, h // 2), (-sw, h // 2)], a["dir"])
        for pts in (head, shaft):
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    draw.polygon([(cx + x + dx, cy + y + dy) for x, y in pts], fill=ARROW_OUTLINE)
        draw.polygon([(cx + x, cy + y) for x, y in head], fill=ARROW_FILL)
        draw.polygon([(cx + x, cy + y) for x, y in shaft], fill=ARROW_FILL)
    return canvas


def draw_dialog(canvas, root_str, lines, ink, paper):
    """Draw the standard bottom text box (rows 12-17) with up to two lines of text."""
    text.draw_textbox_border(canvas, root_str, (0, 12, 20, 6), ink, paper)
    for i, line in enumerate(lines[:2]):
        text.draw_text(canvas, root_str, line, (1, 14 + 2 * i), ink)
    return canvas


# where the hero's 16x16 sprite sits on the 160x144 screen (camera clamps at map edges)
PLAYER_SCREEN = (72, 56)


def render_screen(root_str, label, focus_grid, parent_const=None, sprites=(), arrows=(), dialog=None):
    """Render a native 160x144 GB screen: a viewport of the map centered on `focus_grid`
    (the hero's cell), the given sprites and directional arrows composited, and an optional
    bottom dialog box.

    The camera clamps to the map edges like the game; out-of-map area is filled with paper."""
    full, colors = render_map(root_str, label, parent_const)
    if sprites:
        full = overlay_sprites(full, root_str, sprites, colors)
    if arrows:
        full = overlay_arrows(full, arrows)
    fx, fy = focus_grid[0] * UNIT_PX, focus_grid[1] * UNIT_PX
    offx = min(max(fx - PLAYER_SCREEN[0], 0), max(full.width - SCREEN[0], 0))
    offy = min(max(fy - PLAYER_SCREEN[1], 0), max(full.height - SCREEN[1], 0))
    screen = Image.new("RGB", SCREEN, colors[0])
    screen.paste(full, (-offx, -offy))
    if dialog:
        draw_dialog(screen, root_str, dialog, ink=colors[3], paper=colors[0])
    return screen, colors


# --- battle ------------------------------------------------------------------

def _load_pic(path, size, ramp):
    """Load a 2-bit grayscale battle pic and recolor it onto the ramp (white = paper, opaque)."""
    img = Image.open(path).convert("L")
    rgb = Image.new("RGB", img.size)
    rgb.putdata([_shade_to_ramp(p, ramp) for p in img.getdata()])
    return rgb if img.size == size else rgb.resize(size, Image.NEAREST)


def render_battle(root_str, opponent_const, *, opponent_name=None, palette=sources.PAL_YELLOWMON):
    """Render the pre-battle face-off frame: enemy trainer pic (top-right), player back
    (bottom-left), and the "<NAME> wants / to fight!" dialog. 160x144, native GB pixels.

    `palette` is a PAL_* super-palette id (default the Pikachu-yellow tint) applied to the
    2-bit battle pics; white is the lightest shade (paper), not transparent."""
    ramp = sources.parse_super_palettes(root_str)[palette]
    ink, paper = ramp[3], ramp[0]
    canvas = Image.new("RGB", SCREEN, paper)

    pic_file = sources.parse_trainer_pic_file(root_str, opponent_const)
    enemy = _load_pic(sources._root(root_str) / f"gfx/trainers/{pic_file}.png", (56, 56), ramp)
    canvas.paste(enemy, (96, 0))                                  # hlcoord 12, 0

    back = _load_pic(sources._root(root_str) / "gfx/player/redb.png", (64, 64), ramp)
    canvas.paste(back, (8, 32))                                   # full 2x sprite, feet flush at y=96

    name = opponent_name or sources.parse_trainer_classes(root_str)[opponent_const][1]
    draw_dialog(canvas, root_str, [f"{name} wants", "to fight!"], ink, paper)
    return canvas
