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
MARKER_FILL = (255, 61, 174)       # a flat dot on a hidden-item tile; the site's --neon-magenta #FF3DAE

# The GBC battle screen is colorized (colors sampled from the game). 4-color palettes,
# lightest shade first; white becomes the paper background.
BATTLE_PAPER = (248, 248, 248)
PLAYER_PALETTE = [(248, 248, 248), (234, 183, 78), (206, 6, 53), (16, 16, 16)]   # white/tan/red/black
RIVAL_PALETTE = [(248, 248, 248), (232, 186, 120), (206, 6, 53), (16, 16, 16)]   # white/skin/red/black
BATTLE_INK = (16, 16, 16)
# party Poke balls use the game's PAL_GREENBAR (white/yellow/green/dark): shade 170 is yellow,
# so an empty slot (drawn only in 170) is a yellow circle; a filled ball is green. 255 = bg.
BALL_PALETTE = [None, (238, 210, 74), (43, 201, 32), (24, 24, 24)]

# Which hardware's colors to render in. Set by build.py (--palette); default GBC.
#   "gbc" -> the game's CGBBasePalettes (saturated Game Boy Color)
#   "sgb" -> the paler Super Game Boy SuperPalettes
#   "dmg" -> the original Game Boy's 4 greens (monochrome, one palette everywhere)
PALETTE_MODE = "gbc"
DMG_PALETTE = [(155, 188, 15), (139, 172, 15), (48, 98, 48), (15, 56, 15)]  # #9BBC0F .. #0F380F


def _map_colors(root_str, pal_id):
    """The map's 4 colors (lightest first) for the active PALETTE_MODE."""
    if PALETTE_MODE == "dmg":
        return DMG_PALETTE
    table = sources.parse_super_palettes if PALETTE_MODE == "sgb" else sources.parse_cgb_palettes
    return table(root_str)[pal_id]


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

def _map_painter(root_str, label, parent_const):
    """Return (paint_block, colors, w, h, blk): paint_block(idx) colors one 32x32 block image.

    Shared by render_map (the whole grid) and render_screen (the border block for edge fill)."""
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

    colors = _map_colors(root_str, sources.resolve_palette_id(root_str, const, tileset, parent_const))
    shade_to_rgb = {255: colors[0], 170: colors[1], 85: colors[2], 0: colors[3]}
    tile_cache, block_cache = {}, {}

    def colored_tile(tile_idx):
        if tile_idx not in tile_cache:
            gray = tiles[tile_idx] if tile_idx < len(tiles) else tiles[0]
            rgb = Image.new("RGB", (TILE_PX, TILE_PX))
            rgb.putdata([shade_to_rgb.get(px, colors[0]) for px in gray.getdata()])
            tile_cache[tile_idx] = rgb
        return tile_cache[tile_idx]

    def paint_block(block_idx):
        if block_idx not in block_cache:
            block = blocks[block_idx] if block_idx < len(blocks) else blocks[0]
            img = Image.new("RGB", (BLOCK_PX, BLOCK_PX))
            for ty in range(sources.BLOCK_TILES):
                for tx in range(sources.BLOCK_TILES):
                    img.paste(colored_tile(block[ty * sources.BLOCK_TILES + tx]),
                              (tx * TILE_PX, ty * TILE_PX))
            block_cache[block_idx] = img
        return block_cache[block_idx]

    return paint_block, colors, w, h, blk


def render_map(root_str, label, parent_const=None):
    """Render one pokeyellow map (by header label) to (RGB image, palette colors)."""
    paint_block, colors, w, h, blk = _map_painter(root_str, label, parent_const)
    canvas = Image.new("RGB", (w * BLOCK_PX, h * BLOCK_PX))
    for by in range(h):
        for bx in range(w):
            canvas.paste(paint_block(blk[by * w + bx]), (bx * BLOCK_PX, by * BLOCK_PX))
    return canvas, colors


# --- overlays ----------------------------------------------------------------

def overlay_sprites(canvas, root_str, sprites, colors):
    """Composite 16x16 overworld sprite frames onto a map in the game's CGB object palette.

    Sprites share the map's base palette but through OBP0 (rOBP0 = %11010000): the figure's
    fill (value 1) is base color 0 (white), its detail (value 2) is the map's accent (color 1),
    its outline (value 3) is the dark color, and only the 255 corners are transparent.
    Each sprite: {file, frame, grid:[gx,gy], flip?}; grid is the 16px cell (top-left = grid*16)."""
    out = canvas.convert("RGBA")
    shade = {255: None, 170: colors[0], 85: colors[1], 0: colors[3]}
    for spr in sprites:
        sheet = Image.open(sources._root(root_str) / f"gfx/sprites/{spr['file']}.png").convert("L")
        tile = sheet.crop((0, spr["frame"] * 16, 16, spr["frame"] * 16 + 16))
        if spr.get("flip"):
            tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
        rgba = Image.new("RGBA", (16, 16))
        rgba.putdata([(0, 0, 0, 0) if shade.get(p) is None else (*shade[p], 255) for p in tile.getdata()])
        out.alpha_composite(rgba, (spr["grid"][0] * UNIT_PX, spr["grid"][1] * UNIT_PX))
    return out.convert("RGB")


def overlay_emotes(canvas, root_str, emotes, colors):
    """Composite emotion bubbles (gfx/emotes/*.png) one cell above a sprite, e.g. the '!' a
    trainer flashes on spotting the player. Each emote: {name, grid:[gx,gy]}. The bubble is a
    light fill (shade 170) with a dark outline and mark (shade 0); the corners are transparent."""
    out = canvas.convert("RGBA")
    shade = {255: None, 170: colors[0], 0: colors[3]}
    for em in emotes:
        sheet = Image.open(sources._root(root_str) / f"gfx/emotes/{em['name']}.png").convert("L")
        rgba = Image.new("RGBA", (16, 16))
        rgba.putdata([(0, 0, 0, 0) if shade.get(p) is None else (*shade[p], 255)
                      for p in sheet.crop((0, 0, 16, 16)).getdata()])
        gx, gy = em["grid"]
        out.alpha_composite(rgba, (gx * UNIT_PX, (gy - 1) * UNIT_PX))
    return out.convert("RGB")


def overlay_markers(canvas, markers):
    """Bake a flat brand-pink dot on the center of a cell (a hidden item's tile). The page layers
    the pulsing glow on top in CSS. Each marker: {grid:[gx,gy], r?}."""
    draw = ImageDraw.Draw(canvas)
    for m in markers:
        cx, cy = m["grid"][0] * UNIT_PX + UNIT_PX // 2, m["grid"][1] * UNIT_PX + UNIT_PX // 2
        r = m.get("r", 2)
        draw.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=ARROW_OUTLINE)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MARKER_FILL)
    return canvas


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


# where the hero's 16x16 sprite sits on the 160x144 screen (the fixed Gen 1 camera anchor)
PLAYER_SCREEN = (72, 56)


def _camera(focus_px, anchor, full_size, screen_size):
    """Gen 1 keeps the hero pinned to `anchor` on screen. When the map is wider/taller than the
    screen on this axis we clamp so the camera never scrolls past a map edge; when it is smaller
    we let it center on the hero, so the border block shows in the leftover space (see below)."""
    if full_size < screen_size:
        return focus_px - anchor
    return min(max(focus_px - anchor, 0), full_size - screen_size)


def _border_fill(root_str, label, parent_const):
    """A 160x144 screen tiled with the map's border block (grass/water outdoors, black inside
    buildings), the fill Gen 1 draws in any on-screen cell that falls outside the map."""
    border = sources.parse_border_block(root_str, label)
    paint_block, _, _, _, _ = _map_painter(root_str, label, parent_const)
    tile = paint_block(border if border is not None else 0)
    screen = Image.new("RGB", SCREEN)
    for y in range(0, SCREEN[1], BLOCK_PX):
        for x in range(0, SCREEN[0], BLOCK_PX):
            screen.paste(tile, (x, y))
    return screen


def render_screen(root_str, label, focus_grid, parent_const=None, sprites=(), arrows=(), dialog=None,
                  emotes=(), markers=()):
    """Render a native 160x144 GB screen: a viewport of the map with the hero pinned near the
    center, the given sprites, emotion bubbles, hidden-item markers and directional arrows
    composited, and an optional bottom dialog box.

    Beyond the map edge the screen shows the map's border block, exactly like the game: on a small
    interior map (a gate or shop) that block is solid black, so the empty space reads as black."""
    full, colors = render_map(root_str, label, parent_const)
    if sprites:
        full = overlay_sprites(full, root_str, sprites, colors)
    if emotes:
        full = overlay_emotes(full, root_str, emotes, colors)
    if markers:
        full = overlay_markers(full, markers)
    if arrows:
        full = overlay_arrows(full, arrows)
    fx, fy = focus_grid[0] * UNIT_PX, focus_grid[1] * UNIT_PX
    offx = _camera(fx, PLAYER_SCREEN[0], full.width, SCREEN[0])
    offy = _camera(fy, PLAYER_SCREEN[1], full.height, SCREEN[1])
    screen = _border_fill(root_str, label, parent_const)
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


def render_battle(root_str, opponent_const, *, opponent_name=None, enemy_palette=None,
                  enemy_balls=1, player_balls=1):
    """Render the pre-battle face-off frame: enemy trainer pic (top-right), player back
    (bottom-left), each trainer's party-count Poke balls on their HUD bracket, the
    "<NAME> wants / to fight!" dialog and a continue prompt. 160x144. Colorized in GBC/SGB
    mode; rendered in the Game Boy greens in DMG mode."""
    if PALETTE_MODE == "dmg":
        paper, ink = DMG_PALETTE[0], DMG_PALETTE[3]
        player_pal = enemy_pal = DMG_PALETTE
        ball_pal = [None, DMG_PALETTE[1], DMG_PALETTE[2], DMG_PALETTE[3]]
    else:
        paper, ink = BATTLE_PAPER, BATTLE_INK
        player_pal, enemy_pal, ball_pal = PLAYER_PALETTE, enemy_palette or RIVAL_PALETTE, BALL_PALETTE
    canvas = Image.new("RGB", SCREEN, paper)

    pic_file = sources.parse_trainer_pic_file(root_str, opponent_const)
    enemy = _load_pic(sources._root(root_str) / f"gfx/trainers/{pic_file}.png", (56, 56), enemy_pal)
    canvas.paste(enemy, (96, 0))                                 # hlcoord 12, 0

    back = _load_pic(sources._root(root_str) / "gfx/player/redb.png", (64, 64), player_pal)
    canvas.paste(back, (8, 40))                                  # hlcoord 1, 5: feet on the line at y=96

    filled = _ball_image(root_str, ball_pal, BALL_FILLED_TILE)
    empty = _ball_image(root_str, ball_pal, BALL_EMPTY_TILE)
    _draw_ball_row(canvas, filled, empty, enemy_balls, ENEMY_BALLS_XY, -BALL_STEP)
    _draw_ball_row(canvas, filled, empty, player_balls, PLAYER_BALLS_XY, BALL_STEP)
    _draw_hud(canvas, root_str, ENEMY_HUD, ink)
    _draw_hud(canvas, root_str, PLAYER_HUD, ink)

    name = opponent_name or sources.parse_trainer_classes(root_str)[opponent_const][1]
    draw_dialog(canvas, root_str, [f"{name} wants", "to fight!"], ink, paper)
    text.draw_text(canvas, root_str, "▼", (18, 16), ink)        # continue prompt
    return canvas
