#!/usr/bin/env python3
"""The arrow-tile mazes, walked the way the game pushes you.

A floor like Rocket Hideout B2F is not crossed a step at a time. Stand on an arrow tile and the
game takes the controller off you and plays a fixed run of moves, and which run is not something
to work out from the picture: the disassembly states it outright. Every such floor's script
carries a `map_coord_movement` table (`RocketHideout2ArrowTilePlayerMovement` and its cousins),
one entry per arrow tile, naming an RLE list of pushes, `db PAD_<DIR>, <count>`, read backwards
from the terminating `$FF`. The comment above the table says so and `DecodeRLEList` reads it so.

That makes a maze a graph the game hands us, and the way through it something to solve rather than
trace by eye. A cell you can stand on leads to its walkable neighbours, and stepping onto an arrow
leads wherever the ride ends, however far across the floor that is. `route` then takes the stops
the walkthrough already names (an item ball, a staircase) and returns the cells between them,
so a picture of the way round cannot drift from the floor it is drawn on.
"""
import heapq
import re
from collections import defaultdict
from functools import cache

import markers
import paths
import sources

# Which way each PAD_* button walks the hero, in grid cells.
STEPS = {"LEFT": (-1, 0), "RIGHT": (1, 0), "UP": (0, -1), "DOWN": (0, 1)}

# A slide that chains through more tiles than this is a loop the parser has misread, not a maze:
# the longest real chain in Gen 1 is a handful of hops.
MAX_CHAIN = 32


@cache
def arrow_tiles(root_str, map_label):
    """{(x, y): ((direction, count), ...)} for one map's arrow tiles, or {} if it has none.

    `map_coord_movement` reads x first and `dbmapcoord` swaps the pair on the way into the ROM, so
    the bytes come out y then x, which is the order `DecodeArrowMovementRLE` compares them in
    (`wYCoord` against the first, `wXCoord` against the second). The source order is the one to
    read, and it is already the (x, y) the rest of the tool speaks."""
    body = sources.read_data(root_str, f"scripts/{map_label}.asm", missing_ok=True)
    if body is None:
        return {}

    runs = {label: tuple((direction, int(count)) for direction, count
                         in reversed(re.findall(r"db PAD_(\w+), (\d+)", block)))
            for label, block in re.findall(r"^(\w+ArrowMovement\d+):\n((?:\tdb .*\n)+)", body, re.M)}
    return {(int(x), int(y)): runs[label] for x, y, label
            in re.findall(r"map_coord_movement\s+(\d+),\s*(\d+),\s*(\w+)", body)}


def push_path(cell, pushes):
    """The cells one arrow tile's run walks through, from `cell` to where it stops.

    One entry per step, so a line drawn along it turns exactly where the hero turns."""
    path = [tuple(cell)]
    for direction, count in pushes:
        dx, dy = STEPS[direction]
        for _ in range(count):
            x, y = path[-1]
            path.append((x + dx, y + dy))
    return path


def slide_from(root_str, map_label, cell):
    """Every cell the hero crosses after stepping onto `cell`, until the arrows let go.

    The script re-arms the moment a run finishes, so landing on another arrow tile starts the next
    run and the hops chain into one ride. It ends on the first cell that is not an arrow tile,
    which is where the controller comes back."""
    tiles = arrow_tiles(root_str, map_label)
    path = [tuple(cell)]
    for _ in range(MAX_CHAIN):
        pushes = tiles.get(path[-1])
        if pushes is None:
            return path
        path += push_path(path[-1], pushes)[1:]
    raise ValueError(f"{map_label}: the arrows never let go of {tuple(cell)}")


@cache
def _standing(root_str, map_label):
    """The cells the hero can stand on and still have the controller.

    An arrow tile is not one of them: the script fires the instant your coordinates match it, so
    you pass over it, never stop on it."""
    const, tileset = sources.parse_headers(root_str)[map_label]
    _index, width_blocks, _height = sources.parse_map_constants(root_str)[0][const]
    width, height = markers.map_cells(root_str, const)
    tiles = arrow_tiles(root_str, map_label)
    return frozenset(
        (x, y) for x in range(width) for y in range(height)
        if (x, y) not in tiles
        and markers.cell_is_walkable(root_str, map_label, tileset, width_blocks, (x, y)))


@cache
def _moves(root_str, map_label):
    """{cell: ((next cell, cells crossed to get there), ...)} for one floor.

    Two kinds of move, and the maze is the difference between them: a step onto an open neighbour,
    or a step onto an arrow, which is a step you do not get to take back and which can put you
    most of the way across the floor."""
    standing = _standing(root_str, map_label)
    tiles = arrow_tiles(root_str, map_label)
    out = defaultdict(list)
    for cell in standing:
        for dx, dy in STEPS.values():
            neighbour = (cell[0] + dx, cell[1] + dy)
            if neighbour in standing:
                out[cell].append((neighbour, (cell, neighbour)))
            elif neighbour in tiles:
                ride = slide_from(root_str, map_label, neighbour)
                out[cell].append((ride[-1], (cell, *ride)))
    return {cell: tuple(moves) for cell, moves in out.items()}


def leg(root_str, map_label, start, end):
    """The cells of the shortest way from one cell to another across an arrow floor.

    Shortest by cells travelled, arrow rides included, which is the closest thing to the time it
    takes: a ride is quick per tile but it can throw you a long way from where you wanted to be,
    and counting its tiles is what stops the solver treating a trip across the floor as free."""
    start, end = tuple(start), tuple(end)
    if start == end:
        return [start]

    queue, seen = [(0, start, (start,))], set()
    while queue:
        cost, cell, path = heapq.heappop(queue)
        if cell == end:
            return list(path)
        if cell in seen:
            continue
        seen.add(cell)
        for landing, crossed in _moves(root_str, map_label).get(cell, ()):
            if landing not in seen:
                heapq.heappush(queue, (cost + len(crossed) - 1, landing, path + crossed[1:]))
    raise ValueError(f"{map_label}: no way from {start} to {end}")


def route(root_str, map_label, stops):
    """The whole way round a floor, as one list of cells per leg between the stops it names.

    `stops` is what the walkthrough already says out loud: the doorway you come in by, each ball
    you collect, the doorway you leave by. Everything between them is the game's own answer."""
    return [leg(root_str, map_label, start, end) for start, end in zip(stops, stops[1:], strict=False)]


# Floors whose way through is a plain walk rather than a ride, drawn anyway because the walls are
# invisible: Fuchsia's gym is one open pink room to look at and a maze to cross, and the barriers
# are real collision in the shipped map, so the solver has the answer the player is denied. Each
# names its own stops, because a spin floor's stops are its pins in lettering order while this
# floor's walk ends on the leader, who has to letter last however early you could reach him.
WALKED = {"FuchsiaGym": ("exit-4-17", "trainer-4-10")}


def route_stops(root_str, map_label):
    """The cells a floor's drawn line runs between, or () for a floor that gets no line.

    A line is only ever drawn where the walk is already written down. Everywhere else the pins and
    the steps are enough and a line would be a guess: outside, the flood that orders the pins walks
    up ledges the player can only fall down, so a route drawn from it would trace a way across the
    field that does not exist. Indoors there are no ledges, so the two cases left are the arrow
    floors, where the game states every push, and the floors in WALKED."""
    named = WALKED.get(map_label)
    if named:
        return paths.marker_cells(root_str, map_label, named)
    if not arrow_tiles(root_str, map_label):
        return ()
    return paths.route_cells(root_str, map_label)


def drawn_route(root_str, map_label):
    """The way round one floor as legs of pixel points, or [] for a floor that gets no line.

    Points are pixel centres of their cells, so the app can hang an SVG over the map at its own
    size without having to know the grid."""
    stops = route_stops(root_str, map_label)
    if len(stops) < 2:
        return []
    half = markers.CELL_PX // 2
    return [[[x * markers.CELL_PX + half, y * markers.CELL_PX + half] for x, y in cells]
            for cells in route(root_str, map_label, stops)]
