#!/usr/bin/env python3
"""Turn a map's game data into the marker list the walkthrough page overlays on its area map.

Four categories, each a tick target on the page except exits:
  trainer  every object_event carrying OPP_<CLASS>, <party#>, lettered A, B, C ... per map
  item     every object_event carrying a bare item constant (a ball you can pick up)
  hidden   the map's hidden_events, which show nothing on screen in the game
  exit     the map's warp_events, collapsed so one doorway is one marker

Positions come out as percentages of the rendered PNG, so the page can lay markers over an
image scaled to any width without knowing the tile size.
"""
import string

import sources

CELL_PX = sources.UNIT_PX          # 16; one overworld movement cell
LABEL_FLIP_PCT = 62.0              # past this x the label reads better to the marker's left


def key_letters(index):
    """0 -> A, 25 -> Z, 26 -> AA. Ten trainers on one map is the current maximum, so the
    wrap-around is unreachable today; it exists so a denser map cannot silently collide."""
    letters = string.ascii_uppercase
    out = letters[index % 26]
    index = index // 26
    while index:
        index -= 1
        out = letters[index % 26] + out
        index = index // 26
    return out


def cell_percent(grid_x, grid_y, width_px, height_px):
    """The center of a grid cell as (x%, y%) of the rendered map."""
    return (round((grid_x * CELL_PX + CELL_PX / 2) / width_px * 100, 3),
            round((grid_y * CELL_PX + CELL_PX / 2) / height_px * 100, 3))


def group_warps(warps):
    """Collapse warp_events into one entry per real doorway.

    A gate is several adjacent tiles all pointing at the same map, so group by destination and
    4-neighbour adjacency. Union-find rather than a greedy first-match pass, because two cells
    can belong together only via a third that appears later in the file."""
    parent = list(range(len(warps)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    for i, (x1, y1, dest1, _) in enumerate(warps):
        for j, (x2, y2, dest2, _) in enumerate(warps[i + 1:], start=i + 1):
            if dest1 == dest2 and abs(x1 - x2) + abs(y1 - y2) == 1:
                union(i, j)

    groups = {}
    for i, warp in enumerate(warps):
        groups.setdefault(find(i), []).append(warp)
    return [_warp_group(cells) for cells in groups.values()]


def _warp_group(cells):
    """A doorway's display position is the centroid of its tiles, so a four-tile gate sits at
    its middle; its id anchors to the min cell, which survives the group growing or shrinking."""
    xs, ys = [c[0] for c in cells], [c[1] for c in cells]
    anchor = min((y, x) for x, y in zip(xs, ys))
    return {"dest": cells[0][2],
            "center": (sum(xs) / len(xs), sum(ys) / len(ys)),
            "anchor": (anchor[1], anchor[0])}


def map_edge(grid_x, grid_y, width_cells, height_cells):
    """Which map edge a cell sits on, or 'inner' for a doorway inside the map."""
    if grid_y <= 0:
        return "north"
    if grid_y >= height_cells - 1:
        return "south"
    if grid_x <= 0:
        return "west"
    if grid_x >= width_cells - 1:
        return "east"
    return "inner"


def _marker(cat, anchor, center, width_px, height_px, **fields):
    x, y = cell_percent(center[0], center[1], width_px, height_px)
    return {"id": f"{cat}-{anchor[0]}-{anchor[1]}", "cat": cat, "key": None,
            "x": x, "y": y, "grid": [anchor[0], anchor[1]],
            "align": "l" if x > LABEL_FLIP_PCT else "r", **fields}


def build_markers(root_str, map_label, map_const, width_px, height_px):
    """Every marker for one map, ordered trainers, items, hidden, exits so the page's legend
    groups without re-sorting."""
    objects = sources._object_events(root_str, map_label)
    classes = sources.parse_trainer_classes(root_str)
    out = []

    trainers = [o for o in objects if o["kind"] == "trainer"]
    for i, obj in enumerate(trainers):
        name = classes.get(obj["opp_class"], (0, obj["opp_class"].replace("_", " ")))[1]
        out.append(_marker("trainer", obj["grid"], obj["grid"], width_px, height_px,
                           key=key_letters(i), name=name.title(),
                           ref=f"{obj['opp_class']}:{obj['party']}"))

    for obj in (o for o in objects if o["kind"] == "item"):
        out.append(_marker("item", obj["grid"], obj["grid"], width_px, height_px,
                           name=sources.item_display_name(obj["item_const"]),
                           ref=obj["item_const"]))

    for marker in sources.markers_by_map(root_str).get(map_const, []):
        grid = tuple(marker["grid"])
        out.append(_marker("hidden", grid, grid, width_px, height_px,
                           name=marker["label"], ref=marker["item_const"]))

    width_cells, height_cells = width_px // CELL_PX, height_px // CELL_PX
    for group in group_warps(sources.parse_warp_events(root_str, map_label)):
        anchor = group["anchor"]
        edge = map_edge(anchor[0], anchor[1], width_cells, height_cells)
        entry = _marker("exit", anchor, group["center"], width_px, height_px,
                        name=sources.place_display_name(group["dest"]), ref=group["dest"])
        out.append({**entry, "edge": edge, "glyph": "▲" if entry["y"] < 50 else "▼"})

    return out
