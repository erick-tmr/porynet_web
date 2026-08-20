#!/usr/bin/env python3
"""Turn a map's game data into the marker list the walkthrough page overlays on its area map.

Four categories, each a tick target on the page except exits:
  trainer  every object_event carrying OPP_<CLASS>, <party#>
  item     every object_event carrying a bare item constant (a ball you can pick up)
  hidden   the map's hidden_events, which show nothing on screen in the game
  exit     the map's warp_events, collapsed so one doorway is one marker

Every marker carries a key: its category's letter plus its position among its own kind on that map
(T1, I2, H1, E3). One key names exactly one thing, and any card, step or legend row can print the
key its reader should hunt for. A ladder is the one exception: the Ruby overlay swaps its key for a
bare route-order number, because the steps count ladders rather than naming them.

Positions come out as percentages of the rendered PNG, so the page can lay markers over an
image scaled to any width without knowing the tile size.
"""
from collections import defaultdict

import sources

CELL_PX = sources.UNIT_PX          # 16; one overworld movement cell
LABEL_FLIP_PCT = 62.0              # past this x the label reads better to the marker's left
LABEL_PX = 26                      # a label's own height, the closest two can sit before they touch


# The letter that opens every key, per category. A marker's key is that letter plus its 1-based
# position among its own kind on its own map, so T1 is always a trainer and I2 always an item ball.
# Numbering per category (rather than one run over the whole map) keeps a key stable against
# unrelated edits: adding an item ball renumbers the items and leaves every trainer alone.
KEY_PREFIX = {"trainer": "T", "item": "I", "hidden": "H", "exit": "E", "npc": "N"}


def marker_key(cat, index):
    """('trainer', 0) -> 'T1'. Index is 0-based within the category."""
    return f"{KEY_PREFIX[cat]}{index + 1}"


def cell_percent(grid_x, grid_y, width_px, height_px):
    """The center of a grid cell as (x%, y%) of the rendered map."""
    return (round((grid_x * CELL_PX + CELL_PX / 2) / width_px * 100, 3),
            round((grid_y * CELL_PX + CELL_PX / 2) / height_px * 100, 3))


class Frame:
    """Where one map's cells land on the image the page finally shows.

    A map drawn on its own is its own frame, and this is the identity: cell (0,0) at the top-left,
    percentages against its own PNG. A room cropped into a deck is not (see decks.py): only part of
    it is drawn, somewhere else on a larger canvas, so every marker on it has to be measured there
    instead. `cells` is the half-open crop of the source map that made it in, and `origin` where
    that crop's top-left corner sits on the canvas."""

    def __init__(self, width_px, height_px, cells=None, origin=(0, 0)):
        self.width_px, self.height_px = width_px, height_px
        self.cells, self.origin = cells, origin

    def holds(self, grid_x, grid_y):
        if self.cells is None:
            return True
        x0, y0, x1, y1 = self.cells
        return x0 <= grid_x < x1 and y0 <= grid_y < y1

    def percent(self, grid_x, grid_y):
        x0, y0 = (self.cells[0], self.cells[1]) if self.cells else (0, 0)
        return cell_percent(grid_x - x0 + self.origin[0] / CELL_PX,
                            grid_y - y0 + self.origin[1] / CELL_PX,
                            self.width_px, self.height_px)


# Two doorways that name the same destination *and* the same warp slot in it drop you on the
# identical tile, so if they also sit within a few cells of each other they are one doorway written
# down twice. Gen 1 does that at a cave mouth: beside the ladder it keeps a spare warp a few cells
# into the rock, so walking off the map edge bounces you out rather than stranding you. That spare
# is not a door anyone can reach, and drawing it puts a second "Back outside" pin on solid stone.
# Distance is what separates it from two real doors that happen to share an outdoor tile, like the
# Pokemon Mansion's two south exits, which are twenty cells apart.
SPARE_WARP_REACH = 4


def group_warps(warps):
    """Collapse warp_events into one entry per real doorway.

    A gate is several adjacent tiles all pointing at the same map, so group by destination and
    4-neighbour adjacency. Union-find rather than a greedy first-match pass, because two cells
    can belong together only via a third that appears later in the file. Whatever survives that,
    `drop_spare_warps` then thins of the edge-bounce duplicates described above."""
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
        groups.setdefault(find(i), []).append((i, warp))
    return drop_spare_warps([_warp_group(members) for members in groups.values()])


def drop_spare_warps(groups):
    """Drop any doorway that repeats an earlier one's destination slot from a few cells away.

    Runs on whole groups rather than single tiles, so the middle tile of a wide gate is never
    mistaken for a duplicate of its own neighbours: those are already one group by adjacency."""
    kept = []
    for group in groups:
        if not any(_is_spare_of(group, other) for other in kept):
            kept.append(group)
    return kept


def _is_spare_of(group, other):
    if (group["dest"], group["to"]) != (other["dest"], other["to"]):
        return False
    gx, gy = group["anchor"]
    ox, oy = other["anchor"]
    return abs(gx - ox) + abs(gy - oy) <= SPARE_WARP_REACH


def _warp_group(members):
    """A doorway's display position is the centroid of its tiles, so a four-tile gate sits at
    its middle; its id anchors to the min cell, which survives the group growing or shrinking.

    `slots` are the doorway's own indices in its map's warp list and `to` the index it lands on in
    the destination's, which is what lets two ends of one staircase find each other. The game
    numbers that target from 1, so it is dropped to a 0-based index here."""
    cells = [warp for _, warp in members]
    xs, ys = [c[0] for c in cells], [c[1] for c in cells]
    anchor = min((y, x) for x, y in zip(xs, ys, strict=True))
    return {"dest": cells[0][2],
            "center": (sum(xs) / len(xs), sum(ys) / len(ys)),
            "anchor": (anchor[1], anchor[0]),
            "slots": frozenset(i for i, _ in members),
            "to": cells[0][3] - 1}


EXIT_GLYPHS = {"north": "▲", "south": "▼", "west": "◀", "east": "▶", "inner": "▲"}

# A pass-through building (a cut-through house, a route gate) is small, so its front and back
# doors sit within a few cells of each other. Two same-column doors farther apart than this are a
# cave's separate mouths or a tower's stairwells, not one building.
PASS_THROUGH_MAX_GAP = 8


def label_pass_through_doors(exits):
    """A building you walk straight through has a front door onto the street and a back door behind
    it, both warping to the same interior; left alone the two doors print the same name twice. Tag
    the door facing the street (larger grid y) 'enter' and the one behind it 'exit'. A pass-through
    is a destination reached by exactly two doors in the same column and close together, which
    excludes a cave's far-apart mouths or a multi-floor stairwell."""
    by_dest = defaultdict(list)
    for marker in exits:
        by_dest[marker["ref"]].append(marker)
    for doors in by_dest.values():
        if len(doors) != 2:
            continue
        back, front = sorted(doors, key=lambda m: m["grid"][1])
        same_column = back["grid"][0] == front["grid"][0]
        close = front["grid"][1] - back["grid"][1] <= PASS_THROUGH_MAX_GAP
        if same_column and close:
            front["name"] += " (enter)"
            back["name"] += " (exit)"


# Town and city maps whose own doorways repeat the town name.
TOWN_MAPS = frozenset({
    "PALLET_TOWN", "VIRIDIAN_CITY", "PEWTER_CITY", "CERULEAN_CITY", "VERMILION_CITY",
    "LAVENDER_TOWN", "CELADON_CITY", "FUCHSIA_CITY", "SAFFRON_CITY", "CINNABAR_ISLAND",
})


def strip_town_prefix(exits, map_const):
    """On a town's own map a doorway repeats the town name ('Cerulean Gym', 'Cerulean Mart'); the
    prefix is redundant there and only bloats the label layer, so drop it. Routes, gates and
    dungeons keep their full names. Done before lanes are assigned so they pack the shorter label."""
    if map_const not in TOWN_MAPS:
        return
    prefix = sources.place_display_name(map_const).split()[0] + " "  # 'Cerulean City' -> 'Cerulean '
    for marker in exits:
        if marker["name"].startswith(prefix):
            marker["name"] = marker["name"][len(prefix):]


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


def _marker(cat, anchor, center, frame, **fields):
    x, y = frame.percent(center[0], center[1])
    return {"id": f"{cat}-{anchor[0]}-{anchor[1]}", "cat": cat, "key": None,
            "x": x, "y": y, "grid": [anchor[0], anchor[1]],
            "align": "l" if x > LABEL_FLIP_PCT else "r", **fields}


def build_markers(root_str, map_label, map_const, width_px, height_px, frame=None, keyed=True):
    """Every marker for one map, ordered trainers, items, hidden, exits so the page's legend
    groups without re-sorting.

    `frame` places the map on a composite canvas and drops whatever its crop leaves out; the
    default frame is the map drawn on its own at `width_px` x `height_px`. `keyed` numbers the
    markers here: a deck holds several maps and numbers them once across the lot, so it turns this
    off and calls `assign_keys` itself."""
    frame = frame or Frame(width_px, height_px)
    objects = sources._object_events(root_str, map_label)
    classes = sources.parse_trainer_classes(root_str)
    out = []

    for obj in map_trainers(root_str, map_label):
        name = classes.get(obj["opp_class"], (0, obj["opp_class"].replace("_", " ")))[1]
        out.append(_marker("trainer", obj["grid"], obj["grid"], frame,
                           name=name.title(), ref=f"{obj['opp_class']}:{obj['party']}"))

    for obj in (o for o in objects if o["kind"] == "item"):
        out.append(_marker("item", obj["grid"], obj["grid"], frame,
                           name=sources.item_display_name(obj["item_const"]),
                           ref=obj["item_const"]))

    for marker in sources.markers_by_map(root_str).get(map_const, []):
        grid = tuple(marker["grid"])
        out.append(_marker("hidden", grid, grid, frame,
                           name=marker["label"], ref=marker["item_const"]))

    width_cells, height_cells = map_cells(root_str, map_const)
    warp_markers = []
    for group in group_warps(sources.parse_warp_events(root_str, map_label)):
        anchor = group["anchor"]
        edge = map_edge(anchor[0], anchor[1], width_cells, height_cells)
        entry = _marker("exit", anchor, group["center"], frame,
                        name=sources.place_display_name(group["dest"]), ref=group["dest"])
        warp_markers.append({**entry, "edge": edge, "glyph": EXIT_GLYPHS[edge]})
    label_pass_through_doors(warp_markers)
    strip_town_prefix(warp_markers, map_const)
    out += warp_markers

    tileset = sources.parse_headers(root_str)[map_label][1]
    out += connection_exits(root_str, map_label, map_const, tileset, width_cells // 2,
                            width_cells, height_cells, frame)

    out = [entry for entry in out if frame.holds(*entry["grid"])]
    if not keyed:
        return out
    return assign_label_lanes(assign_keys(out), frame.width_px, frame.height_px)


def map_trainers(root_str, map_label):
    """The trainers a map pins: the ones really standing there when you walk in.

    A trainer the game ships hidden is not, so he gets no pin and takes no letter. The S.S. Anne's
    2F rival is the only one in Kanto: a script walks him into the corridor when you try to leave,
    and a pin for him put a letter on empty carpet and pushed the four cabin trainers down one.
    The roster reads this same list rather than counting for itself, because a floor counted two
    different ways prints one letter on the card and another on the map."""
    return [obj for obj in sources.parse_object_events(root_str, map_label, include_battlers=True)
            if obj["kind"] == "trainer"]


def map_cells(root_str, map_const):
    """A map's size in grid cells, from the game's own map_constants (blocks are two cells)."""
    _index, width_blocks, height_blocks = sources.parse_map_constants(root_str)[0][map_const]
    return width_blocks * 2, height_blocks * 2


def assign_keys(entries):
    """Number the markers within each category, in the order they were built."""
    counts = defaultdict(int)
    for entry in entries:
        cat = entry["cat"]
        entry["key"] = marker_key(cat, counts[cat])
        counts[cat] += 1
    return entries


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


def cell_is_land(root_str, map_label, tileset, width_blocks, cell):
    """True when a cell is dry ground the player can stand on without Surf. This is `cell_is_walkable`
    minus open water, so a shot can keep the hero on the poolside instead of floating mid-water."""
    walkable = sources.parse_collision_tiles(root_str, tileset)
    tileset_file = sources.tileset_basename(root_str, tileset)
    tiles = sources.cell_tiles(root_str, map_label, tileset_file, width_blocks, *cell)
    return any(tile in walkable for tile in tiles)


def cell_is_standable(root_str, map_label, tileset, width_blocks, cell, blueprint=None):
    """True when a sprite can stand on a cell the way the game decides it: its lower-left tile is
    walkable. That is the exact tile Gen 1 keys collision off (`hTilePlayerStandingOn` = `lda_coord
    8, 9`, the sprite's lower-left background tile, in engine/overworld/movement.asm), so a cell
    whose top is open but whose feet sit on a hedge/fence reads as blocked here. Stricter and more
    faithful than `cell_is_land`, which passes on *any* open sub-tile; use this to place a sprite the
    shot draws whole (the hero, the follower), and keep `cell_is_land` for the looser 'could the
    player ever occupy this' that water framing and exit markers want.

    `blueprint` asks the same question of a map in a state it does not ship in, e.g. after the
    player has cut a tree open."""
    walkable = sources.parse_collision_tiles(root_str, tileset)
    tileset_file = sources.tileset_basename(root_str, tileset)
    tiles = sources.cell_tiles(root_str, map_label, tileset_file, width_blocks, *cell, blueprint)
    return tiles[2] in walkable


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


# Connections whose seam carries a land road but also touches a decorative pond, so the generic
# "water is crossed by Surf" rule would anchor the marker to the water instead of the road. Cerulean
# reaches Route 24 over the Nugget Bridge and Route 4 down a road, both flanked by its pond; each end
# is listed so the two sides agree. Keyed by (this map's const, direction).
LAND_CROSSINGS = frozenset({
    ("CERULEAN_CITY", "north"), ("CERULEAN_CITY", "west"),
    ("ROUTE_24", "south"), ("ROUTE_4", "east"),
    ("ROUTE_6", "south"),
})


def nearest_land_crossing(root_str, map_label, tileset, width_blocks, cells):
    """The walkable cell nearest the seam, ignoring water: the road across an edge, not the pond
    beside it."""
    tileset_file = sources.tileset_basename(root_str, tileset)
    walkable = sources.parse_collision_tiles(root_str, tileset)
    land = [c for c in cells
            if any(t in walkable for t in sources.cell_tiles(root_str, map_label, tileset_file,
                                                             width_blocks, *c))] or cells
    mid = cells[len(cells) // 2]
    return min(land, key=lambda cell: (abs(cell[0] - mid[0]) + abs(cell[1] - mid[1]), cell))


def connection_exits(root_str, map_label, map_const, tileset, width_blocks, width_cells,
                     height_cells, frame):
    """One marker per map this one scrolls into, on the part of the edge you can cross."""
    out = []
    dims, _num_city, _first_indoor = sources.parse_map_constants(root_str)
    for direction, dest, offset in sources.parse_connections(root_str, map_label):
        cells = edge_cells(direction, width_cells, height_cells)
        cells = connection_span(cells, direction, offset, dims.get(dest), width_cells, height_cells)
        if (map_const, direction) in LAND_CROSSINGS:
            cell = nearest_land_crossing(root_str, map_label, tileset, width_blocks, cells)
        else:
            cell = crossing_cell(root_str, map_label, tileset, width_blocks, cells)
        entry = _marker("exit", cell, cell, frame,
                        name=sources.place_display_name(dest), ref=dest)
        out.append({**entry, "id": f"exit-{direction}", "edge": direction,
                    "glyph": EXIT_GLYPHS[direction]})
    return out


# A label is Press Start 2P at 9px in a bordered box, offset from its marker. Close enough to
# reserve the right amount of room without measuring text we cannot measure here.
LABEL_CHAR_PX = 8
LABEL_PAD_PX = 18
LABEL_OFFSET_PX = 22
LABEL_KEY_PX = 26          # the key badge ('T1', 'E12') printed ahead of a label's name
NARROW_MAP_DRAWN_PX = 320  # a map too narrow to fill its column is drawn at --mm-max-zoom, not wider


def drawn_width(width_px):
    return max(width_px, NARROW_MAP_DRAWN_PX)


def label_span(entry, width_px):
    """The horizontal band a label occupies, in percent, on whichever side of its marker it sits."""
    text = len(entry["name"]) * LABEL_CHAR_PX + LABEL_PAD_PX + (LABEL_KEY_PX if entry.get("key") else 0)
    basis = drawn_width(width_px)
    width, offset = text / basis * 100, LABEL_OFFSET_PX / basis * 100
    if entry["align"] == "r":
        return (entry["x"] + offset, entry["x"] + offset + width)
    return (entry["x"] - offset - width, entry["x"] - offset)


# How far from its own row a label may be dealt, in lanes either way. A leader line long enough to
# cross the map is harder to follow than the overlap it was drawn to fix, so a crowd past this
# takes the least-covered row it can reach rather than fanning out forever.
LABEL_LANE_REACH = 5

# Two labels exactly one row apart are stacked, not overlapping. The percentages they are measured
# in are rounded, so that case has to be let through rather than caught by a hair.
LANE_EPSILON = 1e-9


def lane_seats(y, row_pct):
    """The rows a label may be dealt into, its own first, then one down, one up, two down, and so
    on. A row that would carry the label off the top or bottom of the map is not offered."""
    yield 0
    for n in range(1, LABEL_LANE_REACH + 1):
        if y + n * row_pct <= 100:
            yield n
        if y - n * row_pct >= 0:
            yield -n


# A map is never drawn smaller than its own pixels: the canvas holds its native width and the frame
# scrolls rather than shrinking the pixel art, and a wide column stretches it to about twice that.
# A label does not stretch with it. Its text stays 9px and the row it is dealt into a flat 26px, so
# the same crowd reads differently at either end of that range: a label dealt upward drifts back
# toward its neighbour above as the map grows under it. A row is chosen against the whole range
# rather than against the one size the PNG happens to be.
LABEL_ZOOMS = (1.0, 1.25, 1.5, 2.0)


def label_covers(span, y, taken, row_pct, zoom):
    """How many already-dealt labels one at `y` covering `span` would print over, at one zoom."""
    return sum(1 for t in taken
               if abs(t["y"] + t["lane"] * row_pct - y) + LANE_EPSILON < row_pct
               and t["spans"][zoom][0] < span[1] and span[0] < t["spans"][zoom][1])


def assign_label_lanes(entries, width_px, height_px):
    """Deal labels that would print over each other into rows of their own.

    Viridian Forest's hidden Potion and the Bug Catcher one cell to its right would otherwise
    write their names on the same pixels. Moving one off its own row always works, where flipping
    it to the marker's other side does not: both of those hug the left edge, so a flipped label
    would hang off the map. Labels that merely share a row but sit far apart are left flat.

    A lane is a row the label is drawn in, not a column it is filed under: what decides a clash is
    where a label ends up, so a label dealt down one row has to be measured against its new
    neighbours and not just against the ones sharing its lane number. Route 8's four Lasses stand
    in a line one cell apart, and lane-by-lane they came out 1, 2, 0, 1: no two shared a lane, and
    every one of them printed over the label of the trainer above or below. Rows are offered
    nearest-first and either way, so a crowd opens outward from where it stands instead of
    cascading down the map, and a label with nowhere clean to go takes the row it covers least,
    counted over every size the map is drawn at (`LABEL_ZOOMS`)."""
    rows = {zoom: LABEL_PX / (height_px * zoom) * 100 for zoom in LABEL_ZOOMS}
    native = LABEL_PX / height_px * 100
    taken = []
    for entry in sorted(entries, key=lambda e: (e["y"], e["x"])):
        spans = {zoom: label_span(entry, width_px * zoom) for zoom in LABEL_ZOOMS}
        seats = [(sum(label_covers(spans[zoom], entry["y"] + lane * rows[zoom], taken, rows[zoom], zoom)
                      for zoom in LABEL_ZOOMS), lane)
                 for lane in lane_seats(entry["y"], native)]
        entry["lane"] = min(seats, key=lambda seat: seat[0])[1]
        taken.append({**entry, "spans": spans})
    return entries


# A staircase is two doorways, one per floor, and the game already says which: a warp names the map
# it leads to and the slot it lands on in that map's warp list. Pairing them up lets both ends wear
# one key, so a reader can see at a glance that E3 on 1F and E3 on B1F are the same steps.
def link_exit_keys(entries, labels, warps_by_label, consts):
    """Re-key the exits of one location's maps so a warp shared by two floors wears one key.

    `entries` are the location's map entries in page order with `labels` parallel to them, and
    `warps_by_label` / `consts` each map's raw warp list and map constant. A doorway leading out of
    the location keeps a key of its own, since its far side is drawn on somebody else's map."""
    doors, by_const = {}, {}
    for label in labels:
        by_const[consts[label]] = label
        for group in group_warps(warps_by_label[label]):
            doors[(label, f"exit-{group['anchor'][0]}-{group['anchor'][1]}")] = group

    def partner(label, group):
        far = by_const.get(group["dest"])
        if far is None:
            return None
        return next((key for key, other in doors.items()
                     if key[0] == far and group["to"] in other["slots"]), None)

    assigned, n = {}, 0
    for entry, label in zip(entries, labels, strict=True):
        for marker in entry["markers"]:
            if marker["cat"] != "exit":
                continue
            here = (label, marker["id"])
            if here not in assigned:
                n += 1
                assigned[here] = marker_key("exit", n - 1)
                group = doors.get(here)
                far = partner(label, group) if group else None
                if far is not None:
                    assigned[far] = assigned[here]
            marker["key"] = assigned[here]
