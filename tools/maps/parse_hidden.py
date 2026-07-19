#!/usr/bin/env python3
"""Extract Pokemon Yellow hidden items + Game Corner coins from pret/pokeyellow.

Adapted from the project handoff (HIDDEN_ITEMS_HANDOFF.md). Verified facts:
- map_const NAME, W, H -> W,H in blocks; 1 block = 32x32 px.
- Overworld coords are the 16px movement grid; cell centre px = (x*16+8, y*16+8).
- data/events/hidden_events.asm 'hidden_event X, Y, FUNC, ARG': FUNC==HiddenItems -> ARG is the item.
- data/events/hidden_coins.asm  'hidden_coin MAP, X, Y' (all GAME_CORNER).

Because we render our own maps at exactly (W*32 x H*32) with no border, the px values
land directly on the render; no scale/offset calibration is needed.
"""
import re
import pathlib

UNIT_PX = 16   # one movement-grid cell in pixels
BLOCK_PX = 32

# item constants pokeyellow spells differently from the display name
_FIXUPS = {"ELIXER": "Elixir", "MAX_ELIXER": "Max Elixir", "HP_UP": "HP Up",
           "PP_UP": "PP Up", "TM": "TM"}


def item_display_name(const):
    if const in _FIXUPS:
        return _FIXUPS[const]
    if const.startswith("TM_") or const.startswith("HM_"):
        return const.replace("_", " ")
    return const.replace("_", " ").title()


def parse_dims(root):
    dims = {}
    for line in (root / "constants/map_constants.asm").read_text().splitlines():
        m = re.match(r"\s*map_const\s+(\w+)\s*,\s*(\d+)\s*,\s*(\d+)", line)
        if m:
            dims[m.group(1)] = (int(m.group(2)), int(m.group(3)))
    return dims


def _cell_px(x, y):
    return [x * UNIT_PX + UNIT_PX // 2, y * UNIT_PX + UNIT_PX // 2]


def parse_hidden_events(root):
    """Return [(map_const, x, y, item_const)] for FUNC == HiddenItems only."""
    out, cur = [], None
    for line in (root / "data/events/hidden_events.asm").read_text().splitlines():
        m = re.match(r"\s*hidden_events_for\s+(\w+)", line)
        if m:
            cur = m.group(1)
            continue
        m = re.match(r"\s*hidden_event\s+(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*(\w+)", line)
        if m and cur and m.group(3) == "HiddenItems":
            out.append((cur, int(m.group(1)), int(m.group(2)), m.group(4)))
    return out


def parse_coins(root):
    """Return [(map_const, x, y)] for hidden coins."""
    out = []
    for line in (root / "data/events/hidden_coins.asm").read_text().splitlines():
        m = re.match(r"\s*hidden_coin\s+(\w+)\s*,\s*(\d+)\s*,\s*(\d+)", line)
        if m:
            out.append((m.group(1), int(m.group(2)), int(m.group(3))))
    return out


def markers_by_map(root):
    """Return {map_const: [ {kind, label, grid:[x,y], px:[x,y]} ]}."""
    root = pathlib.Path(root)
    out = {}
    for const, x, y, item in parse_hidden_events(root):
        out.setdefault(const, []).append(
            {"kind": "item", "label": item_display_name(item), "grid": [x, y], "px": _cell_px(x, y)})
    for const, x, y in parse_coins(root):
        out.setdefault(const, []).append(
            {"kind": "coin", "label": "Coins", "grid": [x, y], "px": _cell_px(x, y)})
    return out


if __name__ == "__main__":
    import sys, json
    root = pathlib.Path(sys.argv[1])
    items = parse_hidden_events(root)
    coins = parse_coins(root)
    print(f"hidden items : {len(items)}")
    print(f"hidden coins : {len(coins)}")
    by_map = markers_by_map(root)
    print(f"maps with markers : {len(by_map)}")
    print(json.dumps(by_map.get("VIRIDIAN_FOREST", []), indent=2))
