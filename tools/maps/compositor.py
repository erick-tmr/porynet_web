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

# The GBC battle screen is colorized (colors sampled from the game). 4-color palettes,
# lightest shade first; white becomes the paper background.
BATTLE_PAPER = (248, 248, 248)
PLAYER_PALETTE = [(248, 248, 248), (234, 183, 78), (206, 6, 53), (16, 16, 16)]   # white/tan/red/black
RIVAL_PALETTE = [(248, 248, 248), (232, 186, 120), (206, 6, 53), (16, 16, 16)]   # white/skin/red/black
BATTLE_INK = (16, 16, 16)
# party Poke balls use the game's PAL_GREENBAR (white/yellow/green/dark): shade 170 is yellow,
# so an empty slot (drawn only in 170) is a yellow circle; a filled ball is green. 255 = bg.
BALL_PALETTE = [None, (238, 210, 74), (43, 201, 32), (24, 24, 24)]

# overworld NPC/player sprites use their own grayscale object palette (sampled from the GBC
# game), not the map palette: the figure's light fill (170) is white, its detail (85) gray, its
# outline (0) black. Only the sprite's 255 corners are transparent (they show the map through).
SPRITE_PALETTE = [None, (248, 248, 248), (112, 112, 112), (24, 24, 24)]

# party Poke balls: the game always shows PARTY_LENGTH slots (SetupPokeballs), filling the
# first N with a real ball and the rest with the empty-slot tile. Screen positions are the
# game's OAM coords minus the hardware (8, 16) offset; each row sits above a HUD bracket. The
# party fills from the base end (enemy: right, stepping left; player: left, stepping right).
PARTY_LENGTH = 6
BALL_FILLED_TILE = 0               # balls.png tile $31: a mon in the slot
BALL_EMPTY_TILE = 3               # balls.png tile $34: an empty slot (open circle)
ENEMY_BALLS_XY = (64, 16)          # first enemy ball, subsequent balls step left
PLAYER_BALLS_XY = (88, 80)         # first player ball, subsequent balls step right
BALL_STEP = 8

# The HUD bracket under each ball row is the game's own tiles, placed exactly as PlaceHUDTiles
# does (draw_hud_pokeball_gfx.asm): (gfx/battle png, tile index, tile_col, tile_row). Tile ids
# come from LoadHudTilePatterns: $73=riser, $74/$77=corners, $76=line, $78/$6F=triangles.
ENEMY_HUD = ([("battle_hud_2", 0, 1, 2), ("battle_hud_2", 1, 1, 3)] +
             [("battle_hud_3", 0, cx, 3) for cx in range(2, 10)] +
             [("battle_hud_3", 2, 10, 3)])
PLAYER_HUD = ([("battle_hud_2", 0, 18, 10), ("battle_hud_3", 1, 18, 11)] +
              [("battle_hud_3", 0, cx, 11) for cx in range(10, 18)] +
              [("battle_hud_1", 2, 9, 11)])

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
    colors = sources.parse_cgb_palettes(root_str)[pal_id]     # 4 RGB tuples, index 0 = lightest
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

def overlay_sprites(canvas, root_str, sprites):
    """Composite 16x16 overworld sprite frames onto a map using the sprite object palette
    (white fill / gray detail / black outline), independent of the map palette.

    Each sprite: {file, frame, grid:[gx,gy], flip?}. Only the sprite's 255 corners are
    transparent; grid is the 16px movement cell, so pixel top-left = grid*16."""
    out = canvas.convert("RGBA")
    shade = {255: SPRITE_PALETTE[0], 170: SPRITE_PALETTE[1], 85: SPRITE_PALETTE[2], 0: SPRITE_PALETTE[3]}
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
        full = overlay_sprites(full, root_str, sprites)
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


def _ball_image(root_str, palette, tile_idx):
    """A party-ball tile from balls.png, colored via `palette` (255 = transparent)."""
    sheet = Image.open(sources._root(root_str) / "gfx/battle/balls.png").convert("L")
    tile = sheet.crop((tile_idx * 8, 0, tile_idx * 8 + 8, 8))
    ball = Image.new("RGBA", (8, 8))
    ball.putdata([(0, 0, 0, 0) if _shade_to_ramp(p, palette) is None else (*_shade_to_ramp(p, palette), 255)
                  for p in tile.getdata()])
    return ball


def _blit_hud_tile(canvas, root_str, png, idx, tile_col, tile_row, ink):
    """Blit one 1bpp HUD tile (dark pixels = ink, light = transparent) at a tile coordinate."""
    sheet = Image.open(sources._root(root_str) / f"gfx/battle/{png}.png").convert("L")
    mask = sheet.crop((idx * 8, 0, idx * 8 + 8, 8)).point(lambda p: 255 if p < 128 else 0).convert("1")
    canvas.paste(ink, (tile_col * 8, tile_row * 8), mask)


def _draw_ball_row(canvas, filled, empty, count, start, step):
    """Draw the party status: PARTY_LENGTH slots, the first `count` filled, the rest empty."""
    x, y = start
    for i in range(PARTY_LENGTH):
        ball = filled if i < count else empty
        canvas.paste(ball, (x, y), ball)
        x += step


def _draw_hud(canvas, root_str, hud, ink):
    """Blit a HUD bracket (its game tiles) under a ball row."""
    for png, idx, tile_col, tile_row in hud:
        _blit_hud_tile(canvas, root_str, png, idx, tile_col, tile_row, ink)


def render_battle(root_str, opponent_const, *, opponent_name=None, enemy_palette=RIVAL_PALETTE,
                  enemy_balls=1, player_balls=1):
    """Render the pre-battle face-off frame: enemy trainer pic (top-right), player back
    (bottom-left), each trainer's green party-count Poke balls on their HUD bracket, the
    "<NAME> wants / to fight!" dialog and a continue prompt. 160x144, colorized GBC look."""
    canvas = Image.new("RGB", SCREEN, BATTLE_PAPER)

    pic_file = sources.parse_trainer_pic_file(root_str, opponent_const)
    enemy = _load_pic(sources._root(root_str) / f"gfx/trainers/{pic_file}.png", (56, 56), enemy_palette)
    canvas.paste(enemy, (96, 0))                                 # hlcoord 12, 0

    back = _load_pic(sources._root(root_str) / "gfx/player/redb.png", (64, 64), PLAYER_PALETTE)
    canvas.paste(back, (8, 40))                                  # hlcoord 1, 5: feet on the line at y=96

    filled = _ball_image(root_str, BALL_PALETTE, BALL_FILLED_TILE)
    empty = _ball_image(root_str, BALL_PALETTE, BALL_EMPTY_TILE)
    _draw_ball_row(canvas, filled, empty, enemy_balls, ENEMY_BALLS_XY, -BALL_STEP)
    _draw_ball_row(canvas, filled, empty, player_balls, PLAYER_BALLS_XY, BALL_STEP)
    _draw_hud(canvas, root_str, ENEMY_HUD, BATTLE_INK)
    _draw_hud(canvas, root_str, PLAYER_HUD, BATTLE_INK)

    name = opponent_name or sources.parse_trainer_classes(root_str)[opponent_const][1]
    draw_dialog(canvas, root_str, [f"{name} wants", "to fight!"], BATTLE_INK, BATTLE_PAPER)
    text.draw_text(canvas, root_str, "▼", (18, 16), BATTLE_INK)  # continue prompt
    return canvas
