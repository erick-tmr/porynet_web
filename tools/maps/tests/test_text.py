import pytest
from PIL import Image

import text


def test_encode_letters_and_punct(root):
    assert text.encode(root, "A") == [0x80]
    assert text.encode(root, "!") == [0xE7]
    assert text.encode(root, "AB C") == [0x80, 0x81, 0x7F, 0x82]


def test_encode_special_chars(root):
    # names carry accented / gender glyphs; the tokenizer must resolve them
    assert text.encode(root, "é") == [0xBA]
    assert text.encode(root, "♂") == [0xEF]


def test_encode_unknown_raises(root):
    with pytest.raises(KeyError):
        text.encode(root, "€")


def test_byte_to_glyph_offsets(root):
    atlas = text.load_font_atlas(root)
    main, extra = atlas
    assert text.byte_to_glyph(atlas, 0x80) is main[0]        # 'A'
    assert text.byte_to_glyph(atlas, 0x7F) is extra[0x1F]    # space (font_extra range)
    with pytest.raises(ValueError):
        text.byte_to_glyph(atlas, 0x52)                      # a control code, no glyph


def test_draw_text_and_border(root):
    canvas = Image.new("RGB", (160, 144), (255, 255, 255))
    text.draw_textbox_border(canvas, root, (0, 12, 20, 6), (0, 0, 0), (255, 255, 255))
    border_ink = sum(1 for p in canvas.crop((0, 96, 160, 144)).getdata() if p == (0, 0, 0))
    text.draw_text(canvas, root, "PORYNET found", (1, 14), (0, 0, 0))
    with_text = sum(1 for p in canvas.crop((0, 96, 160, 144)).getdata() if p == (0, 0, 0))
    assert border_ink > 0                 # the box frame drew ink
    assert with_text > border_ink         # the text added more ink
