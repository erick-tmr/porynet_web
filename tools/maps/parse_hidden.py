#!/usr/bin/env python3
"""Dump the game's hidden items + Game Corner coins (source-of-truth for the walkthrough's
hand-authored hidden-item entries). The parsing lives in sources.py; this is a thin CLI.

  python tools/maps/parse_hidden.py ~/Code/pokeyellow [MAP_CONST]
"""
import json
import sys

import sources

if __name__ == "__main__":
    root = sys.argv[1]
    by_map = sources.markers_by_map(root)
    items = sum(1 for ms in by_map.values() for m in ms if m["kind"] == "item")
    coins = sum(1 for ms in by_map.values() for m in ms if m["kind"] == "coin")
    print(f"hidden items : {items}")
    print(f"hidden coins : {coins}")
    print(f"maps with markers : {len(by_map)}")
    which = sys.argv[2] if len(sys.argv) > 2 else "VIRIDIAN_FOREST"
    print(json.dumps(by_map.get(which, []), indent=2))
