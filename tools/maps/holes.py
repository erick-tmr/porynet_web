#!/usr/bin/env python3
"""The holes you fall down, and the cell each one drops you on.

A hole is not a warp_event. Gen 1 checks the player's cell against a list in the floor's own
script every step (`IsPlayerOnDungeonWarp`, or Pokemon Mansion 3F's inlined copy of it), and the
landing comes out of a pair of tables in `data/maps/special_warps.asm`: `DungeonWarpList` is
(destination map, which hole in the source floor's list, counting from one) and `DungeonWarpData`
is the cell that row drops you on, one row to one row in the same order.

So a floor's holes are read from two places and neither of them is the map file. The ordered cells
are the `dbmapcoord` list the script hands to the dungeon-warp check; a cell's landing is the
`DungeonWarpData` row whose `DungeonWarpList` entry names both this cell's position in that list
and a destination the floor's own script sets. That last clause is what keeps Victory Road 3F
honest: its list holds a switch at position one and the hole at position two, and only the second
has a row, so the switch is never drawn as a hole.

Adjacent cells that drop you on the same tile are one hole written down twice, the way a wide
doorway is several warp_events: Pokemon Mansion 3F's first two cells are a two-tile gap in one
floor, so they group into one marker exactly as `markers.group_warps` groups a gate.
"""
import re
from functools import cache

import sources

# The dungeon-warp check, and the label holding the cells handed to it. Seafoam and Victory Road
# call the shared routine; Pokemon Mansion 3F keeps a copy of it under a local label, which is why
# the match is on what the routine is called rather than on a single name.
CHECK = re.compile(r"ld hl, ([\w.]+)\n\s*(?:call|jp) [\w.]*(?:DungeonWarp|FallingDownHole)")


@cache
def _script(root_str, map_label):
    return sources.read_data(root_str, f"scripts/{map_label}.asm", missing_ok=True)


@cache
def hole_cells(root_str, map_label):
    """The cells one floor hands the dungeon-warp check, in the order the game numbers them.

    Ordered, because the position in this list is the whole of a hole's identity in
    `DungeonWarpList`. Empty for the floors with no holes, which is nearly all of them."""
    body = _script(root_str, map_label)
    if body is None:
        return ()
    named = CHECK.search(body)
    if named is None:
        return ()
    block = re.search(rf"^{re.escape(named.group(1))}:\n((?:\s*dbmapcoord .*\n)+)", body, re.M)
    if block is None:
        return ()
    return tuple((int(x), int(y))
                 for x, y in re.findall(r"dbmapcoord\s+(\d+),\s*(\d+)", block.group(1)))


@cache
def landings(root_str):
    """{(destination map, position in the source floor's hole list): the cell it drops you on}.

    The two tables are parallel rows, so they are zipped rather than searched, and `strict` is the
    guard: a row added to one and not the other would otherwise pair every hole after it with the
    wrong landing."""
    body = sources.read_data(root_str, "data/maps/special_warps.asm")
    listing = re.search(r"^DungeonWarpList:\n((?:\tdb .*\n)+)", body, re.M).group(1)
    data = re.search(r"^DungeonWarpData:\n((?:\tfly_warp .*\n)+)", body, re.M).group(1)
    keys = [(dest, int(slot)) for dest, slot in re.findall(r"db (\w+),\s*(\d+)", listing)]
    cells = [(int(x), int(y))
             for _map, x, y in re.findall(r"fly_warp (\w+),\s*(\d+),\s*(\d+)", data)]
    return dict(zip(keys, cells, strict=True))


def _destination(root_str, map_label, slot):
    """Which map this floor's hole number `slot` drops into, or None when it is not a hole.

    Several floors share a slot number, so the row is picked by naming a destination the floor's
    own script sets. `\\b` on both sides matters: SEAFOAM_ISLANDS_B1F is a substring of the
    TOGGLE_SEAFOAM_ISLANDS_B1F_BOULDER_1 constant sitting a few lines above it."""
    body = _script(root_str, map_label)
    found = [(dest, cell) for (dest, at), cell in landings(root_str).items()
             if at == slot and re.search(rf"\b{dest}\b", body)]
    if len(found) > 1:
        raise ValueError(f"{map_label}: hole {slot} names {len(found)} destinations")
    return found[0] if found else None


def _adjacent(cell, group):
    return any(abs(cell[0] - x) + abs(cell[1] - y) == 1 for x, y in group["cells"])


def _group(groups, cell, slot, dest, landing):
    """Fold one cell into the hole it belongs to, or open a new one for it."""
    for group in groups:
        if (group["dest"], group["landing"]) == (dest, landing) and _adjacent(cell, group):
            group["cells"].append(cell)
            return
    groups.append({"cells": [cell], "slot": slot, "dest": dest, "landing": landing})


def floor_holes(root_str, map_label):
    """One floor's holes: where you fall through, and the floor and cell you land on.

    `anchor` is the min cell, so a hole's id survives the group growing; `center` is the centroid,
    so a two-tile gap in the floor draws its pin between them. `slot` is the position of the first
    cell in the game's own list, which is what the two ends of a drop are paired by."""
    groups = []
    for slot, cell in enumerate(hole_cells(root_str, map_label), start=1):
        drop = _destination(root_str, map_label, slot)
        if drop is not None:
            _group(groups, cell, slot, *drop)
    for group in groups:
        xs, ys = [c[0] for c in group["cells"]], [c[1] for c in group["cells"]]
        anchor = min((y, x) for x, y in group["cells"])
        group["anchor"] = (anchor[1], anchor[0])
        group["center"] = (sum(xs) / len(xs), sum(ys) / len(ys))
    return groups


@cache
def by_map(root_str):
    """Every floor's holes, keyed by the map label they are cut into.

    Only the floors that have any, which in Gen 1 is the four Seafoam floors above B4F, Victory
    Road 3F and Pokemon Mansion 3F."""
    return {label: floor_holes(root_str, label)
            for label in sources.parse_headers(root_str)
            if hole_cells(root_str, label)}


def dropped_boulders(root_str, map_label):
    """Where the boulder each of this floor's holes drops ends up, as (destination map, cell).

    The game does not move a boulder down: it hides the one up here and shows one already placed on
    the floor below, and the two are not always the same cell. Seafoam 1F's east hole is the case,
    at (24, 6) with its boulder appearing two cells west of it, on (22, 6). So a picture that drew
    the drop straight down, or a step that told the reader to look under the hole, would both be
    wrong, and only the object the script names says otherwise.

    In hole order, so it lines up with `floor_holes`. A hole whose script beat cannot be read
    yields None rather than a guess."""
    body = _script(root_str, map_label) or ""
    shown = re.findall(r"ld a, (TOGGLE_\w+)\s*\n\s*ld \[wObjectToShow\], a", body)
    out = []
    for slot, group in enumerate(floor_holes(root_str, map_label)):
        handle = shown[slot] if slot < len(shown) else None
        const = sources.resolve_toggle(root_str, group["dest"], handle) if handle else None
        cell = next((tuple(o["grid"]) for o in _dest_objects(root_str, group["dest"])
                     if o["const"] == const), None)
        out.append((group["dest"], cell))
    return out


def _dest_objects(root_str, map_const):
    label = next(name for name, (const, _tileset) in sources.parse_headers(root_str).items()
                 if const == map_const)
    return sources._object_events(root_str, label)
