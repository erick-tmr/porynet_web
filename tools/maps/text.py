#!/usr/bin/env python3
"""Render Game Boy text from the pokeyellow font atlas + charmap.

A glyph is an 8x8 tile. `constants/charmap.asm` maps each string token to a byte; the byte
selects a tile: bytes >= 0x80 come from gfx/font/font.png (128 glyphs, letters/digits/
punctuation), bytes 0x60..0x7f from gfx/font/font_extra.png (32 glyphs, box-drawing + space).
Both atlases are normalized to an ink mask (a dark source pixel is ink) so the caller can
paint the text in any color, which is how we render the classic bottom dialog box.
"""
from functools import cache

from PIL import Image, ImageDraw

import sources

TILE = sources.TILE_PX   # 8
_INK_THRESHOLD = 128     # source pixel below this is glyph ink

MAIN_BASE = 0x80         # font.png covers 0x80..0xff
EXTRA_BASE = 0x60        # font_extra.png covers 0x60..0x7f


def _slice_tiles(img):
    cols, rows = img.width // TILE, img.height // TILE
    return [img.crop((c * TILE, r * TILE, c * TILE + TILE, r * TILE + TILE))
            for r in range(rows) for c in range(cols)]


@cache
def load_font_atlas(root_str):
    """Return (main, extra): lists of 8x8 'L' glyph tiles for font.png / font_extra.png."""
    root = sources._root(root_str)
    main = _slice_tiles(Image.open(root / "gfx/font/font.png").convert("L"))
    extra = _slice_tiles(Image.open(root / "gfx/font/font_extra.png").convert("L"))
    return main, extra


def byte_to_glyph(atlas, b):
    """Return the 8x8 'L' glyph tile for a charmap byte."""
    main, extra = atlas
    if b >= MAIN_BASE:
        return main[b - MAIN_BASE]
    if EXTRA_BASE <= b < MAIN_BASE:
        return extra[b - EXTRA_BASE]
    raise ValueError(f"byte ${b:02x} is a control code with no glyph")


def _glyph_mask(atlas, b):
    """1-bit ink mask (255 where the glyph is ink) for pasting a solid color."""
    return byte_to_glyph(atlas, b).point(lambda p: 255 if p < _INK_THRESHOLD else 0).convert("1")


@cache
def _max_token_len(root_str):
    return max(len(k) for k in sources.parse_charmap(root_str))


def encode(root_str, text):
    """Tokenize text to charmap bytes, longest-match first (handles é/♂/♀ and multi-char tokens)."""
    charmap = sources.parse_charmap(root_str)
    out, i, n = [], 0, len(text)
    while i < n:
        for length in range(min(_max_token_len(root_str), n - i), 0, -1):
            token = text[i:i + length]
            if token in charmap:
                out.append(charmap[token])
                i += length
                break
        else:
            raise KeyError(f"no charmap glyph for {text[i]!r} in {text!r}")
    return out


def draw_text(canvas, root_str, text, tile_xy, ink):
    """Blit a string onto canvas at a tile coordinate, one 8x8 glyph per character, in `ink`."""
    atlas = load_font_atlas(root_str)
    col, row = tile_xy
    for i, b in enumerate(encode(root_str, text)):
        canvas.paste(ink, ((col + i) * TILE, row * TILE), _glyph_mask(atlas, b))
    return canvas


def draw_textbox_border(canvas, root_str, tile_rect, ink, paper):
    """Reproduce the game's TextBoxBorder: a paper-filled window framed with the box glyphs.

    tile_rect is (col, row, width_tiles, height_tiles); the frame occupies the outermost tiles."""
    col, row, w, h = tile_rect
    ImageDraw.Draw(canvas).rectangle(
        [col * TILE, row * TILE, (col + w) * TILE - 1, (row + h) * TILE - 1], fill=paper)
    right = col + w - 1
    bottom = row + h - 1
    draw_text(canvas, root_str, "┌" + "─" * (w - 2) + "┐", (col, row), ink)
    draw_text(canvas, root_str, "└" + "─" * (w - 2) + "┘", (col, bottom), ink)
    for r in range(row + 1, bottom):
        draw_text(canvas, root_str, "│", (col, r), ink)
        draw_text(canvas, root_str, "│", (right, r), ink)
    return canvas
