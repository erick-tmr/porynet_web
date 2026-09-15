#!/usr/bin/env python3
"""The order the hero meets a floor's trainers, walked rather than read off the map file.

A map file lists its contents in whatever order the disassembly declares them, which is no order
anyone plays in: read straight off, lower Route 10 hands you T2, T3, T5 and T6 for a walk that
meets them T6, T2, T5, T3. So the pins are lettered along the walk instead, and the cards deal out
to match: T1 is the first trainer on the floor, I1 the first item ball you can pick up and H1 the
first hidden one, rather than whichever the assembler happened to list first.

`ROUTES` names the doorways the hero comes in through, in the order the walkthrough enters
them, and everyone is measured from there: a breadth-first flood over the tiles the player can
occupy, so distance is walking distance and a trainer three tiles away behind a ridge sorts after
one thirty tiles down the road. Numbering happens once, in `decks.area_markers`, so a pin and its
card cannot disagree about which trainer is T1.

A pin belongs to the leg whose waypoint is nearest it, and legs come in the order the route lists
them, so one doorway sorts a floor by plain distance and several deal it out leg by leg. That is
what a floor visited more than once needs (Route 10 is split down the middle by Rock Tunnel and
walked as two pages; Mt. Moon B2F is dropped into from three different ladders), and it is also how
a loop is straightened out: the flood walks through boulders, spin tiles and barred doors because
the shipped collision does not know they are shut, so a floor whose guide route the flood cannot
see names the landmarks it turns at, and the pins fall in behind them.
"""
from collections import deque
from functools import cache

import markers
import sources

ROUTES = {
    "Route3": (
        "exit-west", "trainer-16-9", "trainer-10-6", "trainer-14-4", "trainer-19-5",
        "trainer-22-9", "trainer-23-4", "trainer-24-6", "trainer-33-10"
    ),
    "Route6": (
        "exit-17-13", "trainer-0-15", "trainer-10-21", "trainer-11-21", "trainer-19-26",
        "trainer-11-30", "trainer-11-31"
    ),
    "Route8": ("exit-east", "trainer-51-12", "trainer-46-13", "trainer-26-3"),
    "Route9": (
        "exit-west", "trainer-13-10", "trainer-16-15", "trainer-24-7", "trainer-22-2",
        "trainer-45-15", "trainer-40-8", "trainer-31-7", "trainer-43-3", "trainer-48-8"
    ),
    "Route10": ("exit-west", "exit-8-53"),          # from Route 9, then back out of Rock Tunnel
    "Route11": ("exit-west",),                      # east out of Vermilion, off the ship
    "Route12": ("exit-north", "exit-10-21", "trainer-14-31", "trainer-5-39", "trainer-12-40",
                "trainer-9-52", "trainer-14-76", "trainer-6-87", "trainer-11-92"),
    "Route13": (
        "exit-north", "trainer-50-5", "trainer-49-10", "trainer-48-10", "trainer-33-6",
        "trainer-32-6", "trainer-27-9", "trainer-23-10", "trainer-7-13", "trainer-12-4",
        "trainer-10-7"
    ),
    "Route14": ("exit-east",),
    "Route15": (
        "exit-east", "trainer-37-5", "trainer-53-10", "trainer-53-11", "trainer-48-10",
        "trainer-46-10", "trainer-41-10", "trainer-41-11", "trainer-35-13", "trainer-31-13",
        "trainer-18-13"
    ),
    "Route16": (
        "exit-south", "trainer-3-12", "trainer-6-10", "trainer-9-11", "trainer-11-12",
        "trainer-14-13", "trainer-17-12"
    ),
    "Route17": (
        "exit-south", "hidden-8-121", "trainer-10-118",
        "trainer-14-98", "hidden-17-72", "trainer-17-58", "trainer-14-34",
        "hidden-8-45", "trainer-7-32",
        "trainer-2-68", "hidden-4-91", "trainer-5-98",
        "trainer-4-18", "trainer-12-19", "trainer-11-16", "hidden-15-14"
    ),
    "Route18": ("exit-east", "trainer-36-11", "trainer-42-13", "trainer-40-15"),
    "Route19": ("exit-north",),                     # out of Fuchsia
    "Route20": ("exit-east", "exit-48-5", "exit-58-9"),
    "Route2": ("exit-south", "item-13-45", "item-13-54"),
    "Route21": ("exit-south",),                     # north out of Cinnabar
    "Route23": ("exit-7-139", "hidden-8-90", "hidden-19-70", "hidden-9-44"),
    "Route24": ("exit-south",),                     # north out of Cerulean, over the bridge
    "Route25": ("exit-west",),
    "ViridianForest": ("exit-15-47",),              # the Route 2 south gate

    "PewterGym": ("exit-4-13",),
    "CeruleanGym": ("exit-4-13",),
    "VermilionGym": ("exit-4-17",),
    "CeladonGym": ("exit-4-17", "trainer-4-3", "trainer-6-3", "trainer-5-3", "trainer-3-3"),
    "FuchsiaGym": ("exit-4-17",),
    "CinnabarGym": ("exit-16-17",),
    "SaffronGym": ("exit-8-17", "trainer-17-13", "trainer-17-1", "trainer-17-7", "trainer-10-1",
                   "trainer-3-13", "trainer-3-7", "trainer-3-1", "trainer-9-8"),
    "FightingDojo": ("exit-4-11",),
    "ViridianGym": ("exit-16-17", "trainer-2-16", "trainer-3-7", "trainer-12-7", "trainer-11-11",
                    "trainer-10-7", "trainer-13-5", "trainer-10-1", "item-16-9", "trainer-6-5",
                    "trainer-2-1"),

    "SSAnne1F": ("exit-26-0",),                     # up the gangway from the dock
    "SSAnne2F": ("exit-2-4",),
    "SSAnne3F": ("exit-19-3",),
    "SSAnneB1F": ("exit-27-5",),
    "MtMoon1F": (
        "exit-14-35", "trainer-16-23", "item-5-32", "trainer-7-22", "item-2-20", "item-20-33",
        "trainer-24-31", "item-35-31", "trainer-30-27", "item-36-23", "trainer-30-4",
        "trainer-12-16", "item-2-2", "trainer-5-6"
    ),
    "MtMoonB2F": ("exit-15-27", "exit-25-9", "exit-21-17"),
    "RockTunnel1F": ("exit-15-3", "trainer-23-8", "exit-5-3", "exit-17-11", "exit-37-17",
                     "exit-15-33"),
    "RockTunnelB1F": ("exit-33-25", "trainer-14-28", "trainer-20-21", "trainer-30-10",
                      "exit-23-11"),
    "GameCorner": ("exit-15-17",),
    "RocketHideoutB1F": (
        "exit-21-2", "hidden-21-15", "trainer-12-6", "item-11-14", "trainer-26-8",
        "exit-21-24", "trainer-15-25", "trainer-18-17", "item-9-17",
        "exit-24-19", "trainer-28-18"
    ),
    "RocketHideoutB2F": ("exit-27-8", "trainer-20-12", "exit-21-8",
                         "item-1-11", "item-16-8", "item-6-12", "item-3-21",
                         "exit-21-22", "exit-24-19"),
    "RocketHideoutB3F": ("exit-25-6", "trainer-26-12", "item-26-17", "hidden-27-17",
                         "item-20-14", "trainer-10-22", "exit-19-18", "exit-25-6"),
    "RocketHideoutB4F": (
        "exit-19-10", "item-10-12", "item-9-4", "trainer-11-2", "item-10-2",
        "exit-24-15", "item-12-20", "hidden-25-1", "trainer-25-3", "item-25-2"
    ),
    "PokemonTower3F": ("exit-3-9", "trainer-12-3", "trainer-10-13", "trainer-9-8"),
    "PokemonTower4F": ("exit-18-9", "trainer-15-7", "trainer-14-12",
                       "item-12-10", "item-9-10", "item-12-16", "trainer-5-10"),
    "PokemonTower5F": ("exit-3-9",),
    "PokemonTower6F": ("exit-18-9", "trainer-12-10", "item-14-14",
                       "trainer-16-5", "trainer-9-5", "item-6-8"),
    "PokemonMansion1F": ("exit-4-27", "hidden-8-16", "item-14-3", "trainer-17-17", "item-18-21"),
    "PokemonMansion3F": ("exit-7-10", "trainer-5-11", "hidden-1-9", "item-1-16",
                         "exit-6-1", "item-25-5", "trainer-20-11"),
    "PokemonMansionB1F": (
        "exit-23-22", "item-19-25", "trainer-16-23", "item-1-22", "trainer-27-11",
        "item-10-2", "item-5-4", "item-5-13", "hidden-1-9"
    ),
    "SilphCo2F": ("exit-20-0", "trainer-24-7", "trainer-24-13", "trainer-16-11", "trainer-5-12"),
    "SilphCo3F": ("exit-26-0",),
    "SilphCo4F": ("exit-24-0", "trainer-26-10", "trainer-9-14", "trainer-14-6",
                  "item-3-9", "item-4-7", "item-5-8"),
    "SilphCo5F": ("exit-20-0", "hidden-12-3", "trainer-8-16", "item-21-16",
                  "exit-26-0", "trainer-28-4", "trainer-18-10", "trainer-8-3",
                  "item-4-6", "item-2-13"),
    "SilphCo6F": ("exit-14-0",),
    "SilphCo7F": ("exit-22-0", "trainer-20-2", "item-24-11", "trainer-19-14",
                  "trainer-13-1", "trainer-2-13", "item-1-9"),
    "SilphCo8F": ("exit-14-0",),
    "SilphCo9F": ("exit-16-0", "trainer-13-16", "trainer-2-4", "trainer-21-13"),
    "SilphCo10F": ("exit-8-0", "trainer-10-2", "trainer-1-9",
                   "item-5-11", "item-4-14", "item-2-12"),
    "SilphCo11F": ("exit-9-0",),
    "PowerPlant": ("exit-4-35", "pokemon-9-20", "pokemon-32-18", "hidden-17-16", "pokemon-21-25",
                   "item-20-32", "item-26-32", "item-28-3"),
    "UndergroundPathNorthSouth": ("exit-5-4",),     # down from the Route 5 house
    "UndergroundPathWestEast": ("exit-47-2",),      # down from the Route 8 house, walked west
    "CeruleanCave1F": ("exit-24-17", "item-7-11",
                       "exit-23-7", "item-29-16", "hidden-18-7", "item-18-3",
                       "exit-27-1", "item-29-9",
                       "exit-1-3"),
    "CeruleanCave2F": ("exit-3-11", "item-16-7", "hidden-16-13", "item-19-11",
                       "exit-19-7", "item-27-9",
                       "exit-9-1", "item-0-11"),
    "CeruleanCaveB1F": ("exit-3-6", "item-15-3", "hidden-8-14", "item-2-13", "item-3-13",
                        "item-26-1"),
    "SafariZoneEast": ("exit-0-22", "item-20-13", "item-15-12", "item-3-7", "item-21-10"),
    "SafariZoneNorth": ("exit-39-30", "item-19-7", "item-25-1"),
    "SafariZoneWest": ("exit-20-0", "item-19-7", "item-9-7", "hidden-6-5",
                       "exit-29-22", "item-18-18", "item-8-20"),
    "VictoryRoad1F": ("exit-8-17", "item-9-2", "item-11-0", "trainer-7-5", "trainer-3-2"),
    "VictoryRoad2F": (
        "exit-0-8", "trainer-12-9", "item-9-11", "trainer-21-13", "trainer-19-8", "item-18-9",
        "trainer-26-3", "item-27-5",
        "exit-1-1", "trainer-4-2", "hidden-5-2", "item-11-0",
        "exit-27-7", "hidden-26-7"
    ),
    "VictoryRoad3F": ("exit-23-7", "trainer-28-5", "item-26-5", "item-7-7",
                      "exit-2-0", "trainer-13-3", "trainer-6-14", "trainer-7-13"),
}

ROUTE_OVERLAYS = {
    "yellow-legacy": {
        "PowerPlant": ("exit-4-35", "pokemon-9-20", "pokemon-32-18", "hidden-17-16",
                       "pokemon-21-25", "item-20-32", "item-26-32"),
    },
}

GAME = "yellow"

def routes():
    """The waypoints for the game being built."""
    return {**ROUTES, **ROUTE_OVERLAYS.get(GAME, {})}

WARP_MAZES = frozenset({"SaffronGym"})

SWEEP_FROM = {"SSAnne1F": "right", "SSAnne2F": "left"}

WALKED = ("trainer", "item", "pokemon", "hidden")

UNREACHED = 10**6      # a pin no doorway can walk to, sorted after everything that can be reached
STEPS = ((0, 1), (0, -1), (1, 0), (-1, 0))

@cache
def marker_cells(root_str, label, ids):
    """The cells a list of the map's own marker ids sits on, in the order given.

    Marker ids rather than raw coordinates, so a waypoint reads as the thing it is ('exit-8-53' is
    Rock Tunnel's south mouth on Route 10, 'item-1-31' the Poké Ball in the forest's western dead
    end) and stays the same string the walkthrough's own step pins already use."""
    const, _tileset = sources.parse_headers(root_str)[label]
    width_cells, height_cells = markers.map_cells(root_str, const)
    grids = {entry["id"]: tuple(entry["grid"]) for entry in
             markers.build_markers(root_str, label, const,
                                   width_cells * markers.CELL_PX, height_cells * markers.CELL_PX)}
    return tuple(grids[marker_id] for marker_id in ids)

def route_cells(root_str, label):
    """The cells the map's authored route runs through, in order."""
    ids = routes().get(label)
    return marker_cells(root_str, label, ids) if ids else ()

@cache
def reach(root_str, label, start):
    """Walking distance from one cell to every cell the player can reach from it.

    Flood-filled a tile at a time over the same collision the game uses, so the distance between
    two points either side of a ridge is the way round, not the way through. Water counts: a route
    swimmer is fought from a Surf tile, and a shore the guide crosses by boat is still one walk."""
    const, tileset = sources.parse_headers(root_str)[label]
    _index, width_blocks, _height_blocks = sources.parse_map_constants(root_str)[0][const]
    width_cells, height_cells = markers.map_cells(root_str, const)

    def open_cell(cell):
        return 0 <= cell[0] < width_cells and 0 <= cell[1] < height_cells and \
            markers.cell_is_walkable(root_str, label, tileset, width_blocks, cell)

    pads = warp_pads(root_str, label)
    distance = {tuple(start): 0}
    queue = deque([tuple(start)])
    while queue:
        cell = queue.popleft()
        for step in STEPS:
            neighbour = (cell[0] + step[0], cell[1] + step[1])
            if neighbour not in distance and open_cell(neighbour):
                distance[neighbour] = distance[cell] + 1
                queue.append(neighbour)
        landing = pads.get(cell)
        if landing is not None and landing not in distance:
            distance[landing] = distance[cell] + 1
            queue.append(landing)
    return distance

@cache
def warp_pads(root_str, label):
    """{pad cell: where it drops you}, for warps that land on this same map.

    A warp names the map it leads to and the slot it lands on in that map's warp list, so a pad
    leading back into its own map resolves to another of its own cells. Only the maps in
    `WARP_MAZES` get them; anywhere else the flood walks."""
    if label not in WARP_MAZES:
        return {}
    const, _tileset = sources.parse_headers(root_str)[label]
    warps = sources.parse_warp_events(root_str, label)
    return {(x, y): (warps[to - 1][0], warps[to - 1][1])
            for x, y, dest, to in warps if dest == const and 0 < to <= len(warps)}

def distance_to(distance, grid):
    """How far the hero walks to stand in front of a trainer.

    A trainer's own cell is solid to the player, so the distance is to the nearest cell around it,
    which is where you end up when the fight starts."""
    return min(distance.get((grid[0] + dx, grid[1] + dy), UNREACHED)
               for dx, dy in STEPS + ((0, 0),))

def walk_rank(root_str, label, grid):
    """How far along the walk a cell is, as (leg, distance), lowest first.

    The leg is the waypoint nearest the cell, so a floor listing one doorway sorts on distance from
    it alone, and one listing more deals its pins out leg by leg, in the order the guide reaches
    them: a floor visited twice lists both doorways, and a floor the guide loops around lists the
    landmarks it turns at. A cell no waypoint reaches ranks last and keeps its map-file place.

    A cell the route names outright holds exactly the place the route gives it. Nearest-waypoint
    alone cannot promise that: Route 6's two Jr. Trainers stand shoulder to shoulder, so each is a
    step from the other's waypoint and reads as zero away from it. The pair would tie there and
    settle on the map file, whatever order the route had just put them in."""
    cells = route_cells(root_str, label)
    named = next((index for index, cell in enumerate(cells) if cell == tuple(grid)), None)
    if named is not None:
        return (named, 0)
    ranks = [(index, distance_to(reach(root_str, label, cell), grid))
             for index, cell in enumerate(cells)]
    reachable = [rank for rank in ranks if rank[1] < UNREACHED]
    if not reachable:
        return (len(ranks), UNREACHED)
    return min(reachable, key=lambda rank: (rank[1], rank[0]))

def walked(root_str, label, entries, grid_of):
    """`entries` in the order the hero meets them; unchanged for a floor with no authored route.

    Sorting is stable, so trainers that tie (a pair standing shoulder to shoulder) stay in the
    order the map file declares them."""
    if label not in routes():
        return entries
    return sorted(entries, key=lambda entry: walk_rank(root_str, label, grid_of(entry)))

def sort_markers(entries, order):
    """`entries` with each walked category resorted by `order`, in the slots it already held.

    Every category is sorted on its own, because numbering runs per category: an item ball has no
    reason to renumber because a Hiker turned out to be further down the road. Holding the slots
    keeps the categories interleaved exactly as they were, so the exits, which are keyed by a
    scheme of their own, never move."""
    out = list(entries)
    for cat in WALKED:
        slots = [index for index, entry in enumerate(entries) if entry["cat"] == cat]
        for slot, entry in zip(slots, order([entries[i] for i in slots]), strict=True):
            out[slot] = entry
    return out

def walked_markers(root_str, label, entries):
    """One floor's markers with each walked category put in walking order, ready to be numbered."""
    if label not in routes():
        return entries
    return sort_markers(entries, lambda group: walked(root_str, label, group,
                                                     lambda entry: entry["grid"]))

def sweep_key(label):
    """How a swept deck orders a cell, or None for a deck that is walked instead.

    One key for both jobs: the rooms are ordered by the corridor cell each door sits on, and the
    pins inside a room by their own cells. Cells level with each other fall north to south, so a
    sweep never depends on the map file to break a tie."""
    side = SWEEP_FROM.get(label)
    if side is None:
        return None
    across = -1 if side == "right" else 1
    return lambda grid: (across * grid[0], grid[1])
