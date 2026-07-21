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
LABEL_PX = 26                      # a label's own height, the closest two can sit before they touch


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


EXIT_GLYPHS = {"north": "▲", "south": "▼", "west": "◀", "east": "▶", "inner": "▲"}


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
        out.append({**entry, "edge": edge, "glyph": EXIT_GLYPHS[edge]})

    tileset = sources.parse_headers(root_str)[map_label][1]
    out += connection_exits(root_str, map_label, tileset, width_px // sources.BLOCK_PX,
                            width_cells, height_cells, width_px, height_px)

    return assign_label_lanes(out, width_px, height_px)


def edge_cells(direction, width_cells, height_cells):
    """Every cell along one edge of the map, in order."""
    if direction == "north":
        return [(x, 0) for x in range(width_cells)]
    if direction == "south":
        return [(x, height_cells - 1) for x in range(width_cells)]
    if direction == "west":
        return [(0, y) for y in range(height_cells)]
    return [(width_cells - 1, y) for y in range(height_cells)]


def cell_is_walkable(root_str, map_label, tileset, width_blocks, cell):
    """True when a cell is one the player can occupy: land you can stand on (grass, path, floor),
    or open water you can Surf across, which is where a swimmer trainer is fought. A tree, wall,
    fence or ledge is solid. Callers pass in-bounds cells; `cell_tiles` indexes the blueprint
    directly and does not bound-check."""
    walkable = sources.parse_collision_tiles(root_str, tileset)
    tileset_file = sources.tileset_basename(root_str, tileset)
    tiles = sources.cell_tiles(root_str, map_label, tileset_file, width_blocks, *cell)
    return any(tile in walkable for tile in tiles) or all(tile in sources.WATER_TILES for tile in tiles)


def crossing_cell(root_str, map_label, tileset, width_blocks, cells):
    """Where along this edge you actually leave the map.

    A connection spans the whole edge, but only part of it is ground you can cross, so the middle
    of the edge is often a wall or a fence. Pallet Town's way south is open water, four cells left
    of the edge's midpoint, and pointing at the midpoint would point at the beach.

    Water wins when there is any, because an edge with water on it is crossed by Surf."""
    tileset_file = sources.tileset_basename(root_str, tileset)
    walkable = sources.parse_collision_tiles(root_str, tileset)

    def tiles(cell):
        return sources.cell_tiles(root_str, map_label, tileset_file, width_blocks, *cell)

    water = [c for c in cells if all(t in sources.WATER_TILES for t in tiles(c))]
    span = water or [c for c in cells if any(t in walkable for t in tiles(c))] or cells
    # The neighbour aligns its centre with the centre of this strip, so anchor to the strip's
    # midpoint and take the crossable cell nearest it. Both sides then settle on the same seam,
    # where taking the middle of each side's own open span drifts them apart on a broad edge.
    mid = cells[len(cells) // 2]
    return min(span, key=lambda cell: (abs(cell[0] - mid[0]) + abs(cell[1] - mid[1]), cell))


def connection_span(cells, direction, offset, dest_dims, width_cells, height_cells):
    """Narrow an edge to the stretch the neighbouring map actually overlaps.

    A connection spans a strip of the edge, not the whole thing: the header offsets the neighbour
    by `offset` blocks (two cells each) along the shared edge, and it reaches for its own width or
    height of blocks from there. The crossing has to fall inside that overlap. Without this a wide
    city edge picks the middle of every open tile along it, which can land the marker on a beach or
    a field nowhere near the road that actually leaves the map (Viridian's way to Route 22)."""
    if not dest_dims:
        return cells
    _idx, dest_w, dest_h = dest_dims
    vertical = direction in ("west", "east")
    perp, limit = (dest_h, height_cells) if vertical else (dest_w, width_cells)
    start, end = max(0, offset) * 2, min(limit, (offset + perp) * 2)
    return cells[start:end] or cells


def connection_exits(root_str, map_label, tileset, width_blocks, width_cells, height_cells,
                     width_px, height_px):
    """One marker per map this one scrolls into, on the part of the edge you can cross."""
    out = []
    dims, _num_city, _first_indoor = sources.parse_map_constants(root_str)
    for direction, dest, offset in sources.parse_connections(root_str, map_label):
        cells = edge_cells(direction, width_cells, height_cells)
        cells = connection_span(cells, direction, offset, dims.get(dest), width_cells, height_cells)
        cell = crossing_cell(root_str, map_label, tileset, width_blocks, cells)
        entry = _marker("exit", cell, cell, width_px, height_px,
                        name=sources.place_display_name(dest), ref=dest)
        out.append({**entry, "id": f"exit-{direction}", "edge": direction,
                    "glyph": EXIT_GLYPHS[direction]})
    return out


# A label is Press Start 2P at 9px in a bordered box, offset from its marker. Close enough to
# reserve the right amount of room without measuring text we cannot measure here.
LABEL_CHAR_PX = 8
LABEL_PAD_PX = 18
LABEL_OFFSET_PX = 22
LABEL_KEY_PX = 20


def label_span(entry, width_px):
    """The horizontal band a label occupies, in percent, on whichever side of its marker it sits."""
    text = len(entry["name"]) * LABEL_CHAR_PX + LABEL_PAD_PX + (LABEL_KEY_PX if entry.get("key") else 0)
    width, offset = text / width_px * 100, LABEL_OFFSET_PX / width_px * 100
    if entry["align"] == "r":
        return (entry["x"] + offset, entry["x"] + offset + width)
    return (entry["x"] - offset - width, entry["x"] - offset)


def assign_label_lanes(entries, width_px, height_px):
    """Stack labels that would print over each other into lanes, nudging the later one down.

    Viridian Forest's hidden Potion and the Bug Catcher one cell to its right would otherwise
    write their names on the same pixels. Nudging one down always works, where flipping it to
    the marker's other side does not: both of those hug the left edge, so a flipped label would
    hang off the map. Labels that merely share a row but sit far apart are left flat."""
    row_pct = LABEL_PX / height_px * 100
    taken = []
    for entry in sorted(entries, key=lambda e: (e["y"], e["x"])):
        span = label_span(entry, width_px)
        lane = 0
        while any(t["lane"] == lane and abs(t["y"] - entry["y"]) < row_pct
                  and t["span"][0] < span[1] and span[0] < t["span"][1] for t in taken):
            lane += 1
        entry["lane"] = lane
        taken.append({**entry, "span": span})
    return entries
