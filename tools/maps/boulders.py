#!/usr/bin/env python3
"""The way each boulder goes, drawn on the floor it is pushed across.

A Strength boulder is the one thing on these floors the reader has to move rather than walk to,
and prose is a poor way to say it: "one tile west, then four north" is four sentences' worth of
counting squares against a picture that shows neither the square it starts on nor the one it ends
in. The floors already know how to carry a drawn line (`spinners.py` draws the way round an arrow
maze, and the app hangs the same SVG over both the overview and a step's own crop of the floor), so
a push is drawn the same way: one leg per boulder, from where it stands to where it falls, with the
arrowhead on the hole.

Unlike an arrow maze, a push is not something the game states. Where a boulder starts is an
object_event and where it ends is a hole (`holes.py`), but which way round the room it goes is the
walkthrough's own answer, and on Seafoam B3F, where four boulders share two holes, it is a puzzle
with more than one solution. So the corners are written down here beside the steps that describe
them, and what is checked against the game is that the push is one the game allows: every cell dry
ground the boulder can occupy, every shove made from a tile the hero can stand on, and each leg
starting on a boulder the map really places. `test_boulders.py` holds the rest, that the legs end
where the steps say they end.
"""
import holes
import markers
import sources

# The pushes each floor's steps describe, in the order the steps come to them: the cell the boulder
# stands on, then the corners it turns at. A leg is one boulder moved once; a step that moves two
# boulders owns two consecutive legs, which is what lets it crop the floor to both.
PUSHES = {
    # West chamber, then the east one on the way back through.
    "SeafoamIslands1F": (
        ((18, 10), ((17, 10), (17, 6))),
        ((26, 7), ((24, 7), (24, 6))),
    ),
    # Both floors are the same shove twice: the boulder lands beside the next hole and goes in.
    "SeafoamIslandsB1F": (
        ((17, 6), ((18, 6),)),
        ((22, 6), ((23, 6),)),
    ),
    "SeafoamIslandsB2F": (
        ((18, 6), ((19, 6),)),
        ((23, 6), ((22, 6),)),
    ),
    # The four-boulder puzzle. The second from the left goes west to clear the way to the leftmost,
    # which drops straight down its hole; then the right of the pair is parked in the corner so the
    # left one can be walked round to the other hole.
    "SeafoamIslandsB3F": (
        ((5, 14), ((2, 14),)),
        ((3, 15), ((3, 16),)),
        ((9, 14), ((9, 12),)),
        ((8, 14), ((8, 15), (6, 15), (6, 16))),
    ),
}


def cells(start, corners):
    """Every cell a boulder passes through, from where it stands to where it stops."""
    path = [tuple(start)]
    for corner in corners:
        x, y = path[-1]
        step = (_toward(corner[0], x), _toward(corner[1], y))
        while (x, y) != tuple(corner):
            x, y = x + step[0], y + step[1]
            path.append((x, y))
    return path


def _toward(to, here):
    return (to > here) - (to < here)


def _land(root_str, map_label, cell):
    const, tileset = sources.parse_headers(root_str)[map_label]
    width_cells, _height = markers.map_cells(root_str, const)
    return markers.cell_is_land(root_str, map_label, tileset, width_cells // 2, cell)


def check(root_str, map_label):
    """Every push on one floor, checked against the map the game ships.

    Three things, and each is a way the written corners could be wrong rather than a property of
    boulders in general: the leg has to start on a boulder the map places, the boulder has to end
    up somewhere it could be (dry ground, since a boulder shoved into a hole is shoved along the
    floor to it), and every shove has to be made from the cell behind it, which the hero has to be
    able to stand on. A push that fails any of them is a picture of a move nobody can make.

    The raw object list, rather than the one the map loads with: every boulder below 1F is shipped
    hidden and shown when the one above it falls, so the floor you are being told to push it across
    declares it and does not display it."""
    placed = {tuple(o["grid"]) for o in sources._object_events(root_str, map_label)
              if o["sprite_const"] == "SPRITE_BOULDER"}
    dropped = _dropped_onto(root_str, map_label)
    for start, corners in PUSHES.get(map_label, ()):
        if tuple(start) not in placed:
            raise ValueError(f"{map_label}: no boulder stands on {tuple(start)}")
        if tuple(start) in _hidden(root_str, map_label) and tuple(start) not in dropped:
            raise ValueError(f"{map_label}: nothing drops a boulder onto {tuple(start)}")
        path = cells(start, corners)
        for before, after in zip(path[:-1], path[1:], strict=True):
            behind = (before[0] * 2 - after[0], before[1] * 2 - after[1])
            if not _land(root_str, map_label, after):
                raise ValueError(f"{map_label}: a boulder cannot rest on {after}")
            if not _land(root_str, map_label, behind):
                raise ValueError(f"{map_label}: nobody can stand on {behind} to shove {before}")


def _points(path):
    """One push as pixel points: cell centres, less the half cell the boulder itself fills.

    A leg drawn from the middle of the cell the boulder is standing in is drawn over the boulder,
    and the line is thick enough to bury it: a one-cell shove came out as an arrow lying across two
    tiles of bare rock, which is a picture of neither the thing to push nor the hole to push it
    into. Starting at the near edge of that cell instead leaves the boulder whole and loses nothing,
    since where the line begins is the one part of it the reader can already see."""
    half = markers.CELL_PX // 2
    points = [[x * markers.CELL_PX + half, y * markers.CELL_PX + half] for x, y in path]
    (x0, y0), (x1, y1) = points[0], points[1]
    return [[x0 + (x1 - x0) // 2, y0 + (y1 - y0) // 2], *points[1:]]


def drawn_pushes(root_str, map_label):
    """One floor's pushes as legs of pixel points, the way `spinners.drawn_route` draws a ride.

    Empty for every floor that has none, which is every floor in the game outside Seafoam."""
    if map_label not in PUSHES:
        return []
    check(root_str, map_label)
    return [_points(cells(start, corners)) for start, corners in PUSHES[map_label]]


def _hidden(root_str, map_label):
    """The boulder cells the map declares but does not show when it loads."""
    const = sources.parse_headers(root_str)[map_label][0]
    off = sources.parse_hidden_objects(root_str).get(const, set())
    return {tuple(o["grid"]) for o in sources._object_events(root_str, map_label)
            if o["sprite_const"] == "SPRITE_BOULDER" and o["const"] in off}


def _dropped_onto(root_str, map_const_label):
    """Every cell some hole in the location drops a boulder onto this floor.

    A boulder that is not on the floor when it loads got there by falling, so this is where it can
    legally be pushed from. The game states it outright, in the object the falling floor's script
    reveals, and it is not always the cell under the hole: `holes.dropped_boulders` has the two
    Seafoam pairs that land off to one side."""
    const = sources.parse_headers(root_str)[map_const_label][0]
    return {cell for label in holes.by_map(root_str)
            for dest, cell in holes.dropped_boulders(root_str, label)
            if dest == const and cell is not None}


def boulder_cells(root_str, map_label):
    """Where to draw a boulder for each of this floor's pushes, as cell-centre pixels.

    The app draws them over a step's own crop rather than the generator baking them into the map.
    Every boulder below Seafoam 1F is shipped hidden and revealed when the one above it falls, so a
    floor drawn as the game loads it has none: baking them in would have the floor overview
    claiming boulders that are not there yet, and leaving them out left the push pictures pointing
    an arrow across bare rock. Drawn per leg, so only the steps that push one show one."""
    half = markers.CELL_PX // 2
    return [[start[0] * markers.CELL_PX + half, start[1] * markers.CELL_PX + half]
            for start, _corners in PUSHES.get(map_label, ())]


def ends_in_a_hole(root_str, map_label, leg):
    """Whether one push drops its boulder rather than parking it out of the way."""
    ends = {group["anchor"] for group in holes.by_map(root_str).get(map_label, ())}
    return leg[-1] in ends
