#!/usr/bin/env python3
"""Draw a deck: a corridor map and the rooms you reach from it, composed into one picture.

Gen 1 keeps a floor's rooms on a map of their own. SS_ANNE_1F_ROOMS holds all six 1F cabins in a
3x2 grid, so the ship was two pictures a reader had to hold at once: a corridor of six identical
doors, and a grid of six identical cabins, tied together only by the letter each pin happened to
wear. A deck crops each room out of that shared map, hangs it off the door it belongs to, and runs
a connector between the two, so which cabin is behind which door is something you can see.

Nothing here is configured per map. A doorway has exactly one walkable neighbour inside the
corridor, the tile you stand on to step through it, so the room lies on the corridor's far side
from that. Each room lines its own doorway up with the corridor's, so every connector is a
straight run. A room that would overlap one already placed falls to the next row out, which is how
1F's kitchen ends up below its cabins instead of through them.
"""
from collections import defaultdict, namedtuple

from PIL import ImageDraw

import compositor
import locations
import markers
import sources

CELL = sources.UNIT_PX
GAP = 2 * CELL             # the run a connector makes from a corridor to the room off it
LINE_PX = 4                # connector thickness
EDGE_PX = 2                # its dark outline, the same ink the pointer arrows wear
SEAM_PX = 3                # the seam drawn round a room so neighbours do not merge

STEP = {"north": (0, -1), "south": (0, 1), "west": (-1, 0), "east": (1, 0)}
OPPOSITE = {"north": "south", "south": "north", "west": "east", "east": "west"}

# `cells` is the half-open crop of the source map that is drawn, in cells; `origin` where that
# crop's top-left corner lands on the deck, in pixels. The corridor is a placement like any other,
# always first, cropped to the whole map.
Placement = namedtuple("Placement", "label floor cells origin")
Deck = namedtuple("Deck", "width height placements connectors")


def room_crop(root_str, map_label, cell):
    """The room holding `cell`, as a half-open cell rectangle.

    A shared rooms map is a grid of rooms with the border block flooded between them, so a room is
    an island of blocks that are not the border, and flood-filling from the doorway finds exactly
    the one you walked into. A map with no border block inside it (a kitchen, the bow deck) is one
    island and comes back whole."""
    const = sources.parse_headers(root_str)[map_label][0]
    _index, width, height = sources.parse_map_constants(root_str)[0][const]
    blocks = sources.load_blueprint(root_str, map_label)
    border = sources.parse_border_block(root_str, map_label)

    start = (cell[0] // 2, cell[1] // 2)
    seen, stack = {start}, [start]
    while stack:
        bx, by = stack.pop()
        for nx, ny in ((bx + 1, by), (bx - 1, by), (bx, by + 1), (bx, by - 1)):
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen \
                    and blocks[ny * width + nx] != border:
                seen.add((nx, ny))
                stack.append((nx, ny))
    xs, ys = [b[0] for b in seen], [b[1] for b in seen]
    return (min(xs) * 2, min(ys) * 2, (max(xs) + 1) * 2, (max(ys) + 1) * 2)


def room_side(root_str, corridor_label, anchor):
    """Which way the room lies from its doorway.

    Read out of the game rather than configured: the doorway sits in a wall with exactly one open
    tile beside it, the one you stand on to use it, so the room is on the opposite side. A doorway
    open more ways than that is not a doorway into a room, and this says so rather than guessing."""
    const, tileset = sources.parse_headers(root_str)[corridor_label]
    width_cells, height_cells = markers.map_cells(root_str, const)
    width_blocks = width_cells // 2
    x, y = anchor
    inside = [side for side, (dx, dy) in STEP.items()
              if 0 <= x + dx < width_cells and 0 <= y + dy < height_cells
              and markers.cell_is_walkable(root_str, corridor_label, tileset, width_blocks,
                                           (x + dx, y + dy))]
    if len(inside) != 1:
        raise ValueError(f"{corridor_label}: the doorway at {anchor} is open on {len(inside)} "
                         "sides, so which side its room lies on is not something the map says")
    return OPPOSITE[inside[0]]


def _doorways(root_str, corridor_label, room_consts):
    """The corridor's doorways into the rooms drawn with it, in reading order, so the rooms end up
    laid out the way you walk past their doors."""
    groups = markers.group_warps(sources.parse_warp_events(root_str, corridor_label))
    return sorted((g for g in groups if g["dest"] in room_consts),
                  key=lambda g: (g["anchor"][1], g["anchor"][0]))


def _center_px(center):
    """A warp group's centroid, in pixels from the top-left of the map it sits on."""
    return (center[0] * CELL + CELL / 2, center[1] * CELL + CELL / 2)


def _row_for(rows, span, depth):
    """The first row out from the corridor where this room clears everything already placed."""
    for index, row in enumerate(rows):
        if all(span[1] <= start or end <= span[0] for start, end in row["spans"]):
            row["spans"].append(span)
            row["extent"] = max(row["extent"], depth)
            return index
    rows.append({"spans": [span], "extent": depth})
    return len(rows) - 1


def plan(root_str, corridor_label, floor, rooms):
    """Lay out a deck. `rooms` is the [(map label, floor label)] drawn into the corridor's image.

    Rows are settled for every room before any origin is worked out, because a room landing in row
    0 late can make that row deeper and would otherwise leave row 1 overlapping it."""
    headers = sources.parse_headers(root_str)
    by_const = {headers[label][0]: (label, room_floor) for label, room_floor in rooms}
    corridor_size = [n * CELL for n in markers.map_cells(root_str, headers[corridor_label][0])]

    rows, staged = defaultdict(list), []
    for door in _doorways(root_str, corridor_label, by_const):
        label, room_floor = by_const[door["dest"]]
        warps = sources.parse_warp_events(root_str, label)
        crop = room_crop(root_str, label, warps[door["to"]][:2])
        far = next(g for g in markers.group_warps(warps) if door["to"] in g["slots"])

        side = room_side(root_str, corridor_label, door["anchor"])
        here = _center_px(door["center"])
        there = _center_px((far["center"][0] - crop[0], far["center"][1] - crop[1]))
        size = ((crop[2] - crop[0]) * CELL, (crop[3] - crop[1]) * CELL)
        axis = 0 if side in ("north", "south") else 1
        start = here[axis] - there[axis]
        row = _row_for(rows[side], (start, start + size[axis]), size[1 - axis])
        staged.append((label, room_floor, crop, side, row, start, size, here, there))

    placements = [Placement(corridor_label, floor, (0, 0, *[n // CELL for n in corridor_size]),
                            (0, 0))]
    connectors = []
    for label, room_floor, crop, side, row, start, size, here, there in staged:
        depth = GAP + sum(r["extent"] + GAP for r in rows[side][:row])
        origin = {
            "south": (start, corridor_size[1] + depth),
            "north": (start, -depth - size[1]),
            "east": (corridor_size[0] + depth, start),
            "west": (-depth - size[0], start),
        }[side]
        placements.append(Placement(label, room_floor, crop, origin))
        connectors.append((here, (origin[0] + there[0], origin[1] + there[1])))

    return _normalize(placements, connectors)


def _normalize(placements, connectors):
    """Shift everything so the deck starts at (0, 0), and measure the canvas it needs.

    A doorway several tiles wide has a centroid on a half cell, so an origin can land off the grid;
    round to whole pixels before measuring, or the canvas comes out a fraction of a pixel wide."""
    placed = [p._replace(origin=(round(p.origin[0]), round(p.origin[1]))) for p in placements]
    left = min(p.origin[0] for p in placed)
    top = min(p.origin[1] for p in placed)
    moved = [p._replace(origin=(p.origin[0] - left, p.origin[1] - top)) for p in placed]
    width = max(p.origin[0] + (p.cells[2] - p.cells[0]) * CELL for p in moved)
    height = max(p.origin[1] + (p.cells[3] - p.cells[1]) * CELL for p in moved)
    lines = [((a[0] - left, a[1] - top), (b[0] - left, b[1] - top)) for a, b in connectors]
    return Deck(width, height, moved, lines)


def render(root_str, deck, parent_const, draw_map):
    """Paint a planned deck. `draw_map(label)` renders one source map with its people on it.

    Everything a deck does not cover is filled with the corridor's own border block, the same
    thing the game shows beyond a map's edge: solid black inside the ship, so the rooms read as
    lit boxes hanging in the dark rather than as pieces of one floor plan."""
    corridor = deck.placements[0]
    canvas = compositor.border_fill(root_str, corridor.label, parent_const, deck.width, deck.height)
    for place in deck.placements:
        x0, y0, x1, y1 = place.cells
        crop = draw_map(place.label).crop((x0 * CELL, y0 * CELL, x1 * CELL, y1 * CELL))
        canvas.paste(crop, place.origin)

    draw = ImageDraw.Draw(canvas)
    # Doors along a corridor sit exactly one room apart, so rooms hung off them land edge to edge
    # and five cabins read as one long hall. Outlining each room in the void's own ink puts a seam
    # back between them; it costs a couple of pixels off an outer wall and nothing else.
    for place in deck.placements[1:]:
        draw.rectangle(_bounds(place), outline=compositor.ARROW_OUTLINE, width=SEAM_PX)
    for width, color in ((LINE_PX + 2 * EDGE_PX, compositor.ARROW_OUTLINE),
                         (LINE_PX, compositor.ARROW_FILL)):
        for start, end in deck.connectors:
            draw.line([start, end], fill=color, width=width)
    return canvas


def _bounds(place):
    """A placement's rectangle on the deck, in pixels."""
    return (place.origin[0], place.origin[1],
            place.origin[0] + (place.cells[2] - place.cells[0]) * CELL - 1,
            place.origin[1] + (place.cells[3] - place.cells[1]) * CELL - 1)


def deck_markers(root_str, deck):
    """Every marker on a deck, measured on the composite and numbered once across the whole thing.

    A room's own door back to the corridor is dropped. The corridor's pin already names that
    doorway, the connector shows what is behind it, and two pins for one door would burn two
    letters on the same instruction."""
    corridor = deck.placements[0]
    home = sources.parse_headers(root_str)[corridor.label][0]
    out = []
    for place in deck.placements:
        const = sources.parse_headers(root_str)[place.label][0]
        frame = markers.Frame(deck.width, deck.height, place.cells, place.origin)
        entries = markers.build_markers(root_str, place.label, const, deck.width, deck.height,
                                        frame=frame, keyed=False)
        if place is not corridor:
            entries = [e for e in entries if not (e["cat"] == "exit" and e["ref"] == home)]
        out += entries

    ids = [entry["id"] for entry in out]
    if len(set(ids)) != len(ids):
        raise ValueError(f"{corridor.label}: two markers on this deck share an id, so a step "
                         "pointing at one would tick the other")
    _shorten_door_names(out, home)
    return markers.assign_label_lanes(markers.assign_keys(out), deck.width, deck.height)


def _shorten_door_names(entries, corridor_const):
    """Drop the words a doorway's name shares with the deck it is drawn on.

    Six doors labelled "S.S. Anne 1F Rooms" over one corridor is the ship's own name read six
    times and the one useful word buried at the end; on 1F's map they overlapped each other as
    well. Sharing leading words with the map you are standing on is exactly what makes a word
    redundant, so those go and "Rooms", "Kitchen", "B1F" remain. A doorway off the ship keeps its
    whole name, having nothing in common to drop."""
    here = sources.place_display_name(corridor_const).split()
    for entry in entries:
        if entry["cat"] != "exit":
            continue
        words = entry["name"].split()
        shared = 0
        while shared < min(len(here), len(words) - 1) and here[shared] == words[shared]:
            shared += 1
        entry["name"] = " ".join(words[shared:])


def area_markers(root_str, label, floor, width_px, height_px):
    """The markers for one drawn floor, whether it is a plain map or a deck.

    The single place that decides, so the build, the trainer roster and the golden manifest test
    cannot come to different answers about what a floor holds or how its pins are numbered. A deck
    measures itself, so the size passed in is only used for a map drawn on its own."""
    rooms = locations.attached(label)
    if not rooms:
        const = sources.parse_headers(root_str)[label][0]
        return markers.build_markers(root_str, label, const, width_px, height_px)
    return deck_markers(root_str, plan(root_str, label, floor, rooms))


def holds(place, grid):
    """Whether a source-map object falls inside this placement's crop."""
    x0, y0, x1, y1 = place.cells
    return x0 <= grid[0] < x1 and y0 <= grid[1] < y1
