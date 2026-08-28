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

# map label -> the hero's route across it, as marker ids in the order they are reached: the doorway
# it is entered by, then any pin the flood alone would put in the wrong order. A waypoint can be
# anything the map draws, a trainer included, for the floors where the best order to clear them is
# a judgement about backtracking rather than a matter of who is nearest the door. A floor is
# listed once it has two of anything to sort (trainers, item balls or hidden items); anything
# shorter reads the same either way.
ROUTES = {
    # Routes, entered from whichever neighbour the guide arrives from.
    # Out of Pewter, then the order that clears the eight of them with the least walking back:
    # the Lass on the entrance row before the Bug Catcher up the bank, and the Youngster on the
    # low road before the Lass above him. Neither pair is settled by distance from the gate.
    "Route3": (
        "exit-west", "trainer-16-9", "trainer-10-6", "trainer-14-4", "trainer-19-5",
        "trainer-22-9", "trainer-23-4", "trainer-24-6", "trainer-33-10"
    ),
    # Up from the Underground Path, then straight down the road. The Bug Catcher on the west fence
    # is a long walk sideways but only two rows below where you surface, so you pass his line before
    # the pair of Jr. Trainers further south; distance from the stairs alone puts him fourth.
    "Route6": (
        "exit-17-13", "trainer-0-15", "trainer-10-21", "trainer-11-21", "trainer-19-26",
        "trainer-11-30", "trainer-11-31"
    ),
    # Out of Lavender. The four standing in a column halfway along are cleared in one pass down
    # it, so you come west along the top row and take them from the north end; the flood arrives
    # on the bottom row and letters the column upside down, which is a walk that climbs it and
    # then comes back down for the road west.
    "Route8": ("exit-east", "trainer-51-12", "trainer-46-13", "trainer-26-3"),
    # Out of Cerulean, and the way across is a staircase of one-way ledges the flood cannot see:
    # it walks up drops the player can only fall down, so it reads the route as open field and
    # ranks nine trainers on how far east they sit. Walked, the low road comes before the pocket
    # above it every time: the Youngster on the road before the Bug Catcher up in the northern
    # bowl, the Hiker in the southeast hollow before the Bug Catcher on the shelf over it, then up
    # onto the ridge and out along the top.
    "Route9": (
        "exit-west", "trainer-13-10", "trainer-16-15", "trainer-24-7", "trainer-22-2",
        "trainer-45-15", "trainer-40-8", "trainer-31-7", "trainer-43-3", "trainer-48-8"
    ),
    "Route10": ("exit-west", "exit-8-53"),          # from Route 9, then back out of Rock Tunnel
    "Route11": ("exit-west",),                      # east out of Vermilion, off the ship
    # Down from Lavender, then out of the gate's south door: the flood cannot walk through the
    # building, so from the north end alone every pin on the route reads as unreachable and the
    # whole page falls back to map-file order. Past the door the boards are the walk but the flood
    # swims the bay between them, which hands the Fisherman on the east planks to the reader before
    # the one two rows above him on the west side, so the seven are named outright.
    "Route12": ("exit-north", "exit-10-21", "trainer-14-31", "trainer-5-39", "trainer-12-40",
                "trainer-9-52", "trainer-14-76", "trainer-6-87", "trainer-11-92"),
    # Down out of Route 12 and west along the ledges. The exit is on the west side, so the
    # southwest pocket, one Bird Keeper and the buried PP Up, is a detour taken on the way past
    # rather than the last thing on the road, and the Biker beside the gate is the last one you
    # meet on the way out. Measuring from the doorway alone the flood deals all three out
    # backwards, so the tail of the route is named.
    "Route13": (
        "exit-north", "trainer-50-5", "trainer-49-10", "trainer-48-10", "trainer-33-6",
        "trainer-32-6", "trainer-27-9", "trainer-23-10", "trainer-7-13", "trainer-12-4",
        "trainer-10-7"
    ),
    "Route14": ("exit-east",),
    # Two lanes with a run of one-way ledges between them, so the flood walks up drops you can
    # only fall down and reads the route as one open field. Walked, the top lane is taken first
    # (in off Route 14, west past the Jr. Trainer to TM20 Rage in the corner), then back east to
    # hop the ledge down, and the bottom lane is swept right to left on the way to Fuchsia.
    "Route15": (
        "exit-east", "trainer-37-5", "trainer-53-10", "trainer-53-11", "trainer-48-10",
        "trainer-46-10", "trainer-41-10", "trainer-41-11", "trainer-35-13", "trainer-31-13",
        "trainer-18-13"
    ),
    "Route16": ("exit-south",),                     # up out of Cycling Road, then east to Celadon
    # Climbed, not coasted: the guide comes up from Fuchsia, so the road is lettered from its foot.
    # The only ledges on it are the seven along the bottom row, and two gaps in them let you walk
    # back up, so the climb is real; everything above that row is open both ways. Naming the ten
    # is what fixes the pairs level with each other, which the flood deals out left-first: the
    # rider takes the near side of the road going up, so the right of each pair comes first.
    "Route17": (
        "exit-south", "trainer-10-118", "trainer-14-98", "trainer-5-98", "trainer-2-68",
        "trainer-17-58", "trainer-14-34", "trainer-7-32", "trainer-12-19", "trainer-4-18",
        "trainer-11-16"
    ),
    # Three Bird Keepers in a cluster by the Fuchsia gate, and the flood splits the pair on the
    # right the wrong way round: the one on the upper shelf is met before the one below it, whichever
    # end of the route you come in from, so the order is named.
    "Route18": ("exit-east", "trainer-36-11", "trainer-42-13", "trainer-40-15"),
    "Route19": ("exit-north",),                     # out of Fuchsia
    "Route20": ("exit-east",),
    "Route2": ("exit-south", "item-13-45", "item-13-54"),
    "Route21": ("exit-south",),                     # north out of Cinnabar
    "Route23": ("exit-7-139", "hidden-8-90", "hidden-19-70", "hidden-9-44"),
    "Route24": ("exit-south",),                     # north out of Cerulean, over the bridge
    "Route25": ("exit-west",),
    "ViridianForest": ("exit-15-47",),              # the Route 2 south gate

    # Gyms, all of them one room off one door.
    "PewterGym": ("exit-4-13",),
    "CeruleanGym": ("exit-4-13",),
    "VermilionGym": ("exit-4-17",),
    # Erika's chamber is sealed until you cut into it, and a gym hedge is solid to the shipped
    # collision, so the flood stops outside and the four people in there would fall back to
    # map-file order. They are named outright instead: the leader first, since the chamber is hers
    # and her letter anchors it, then the three around her in the order you meet them coming
    # through the east hedge.
    "CeladonGym": ("exit-4-17", "trainer-4-3", "trainer-6-3", "trainer-5-3", "trainer-3-3"),
    "FuchsiaGym": ("exit-4-17",),
    "CinnabarGym": ("exit-16-17",),
    "SaffronGym": ("exit-8-17",),
    "ViridianGym": ("exit-16-17",),

    # Caves and buildings, entered by the ladder or staircase the steps take.
    "SSAnne1F": ("exit-26-0",),                     # up the gangway from the dock
    "SSAnne2F": ("exit-2-4",),
    "SSAnne3F": ("exit-19-3",),
    "SSAnneB1F": ("exit-27-5",),
    # 1F is walked as a loop, and the Youngster is the case the flood cannot see: he stands a few
    # cells off the path east to the first ladder, and you do not actually meet him until you come
    # back up it and turn northwest for the Moon Stone, next to last before the Hiker.
    "MtMoon1F": (
        "exit-14-35", "trainer-16-23", "item-5-32", "trainer-7-22", "item-2-20", "item-20-33",
        "trainer-24-31", "item-35-31", "trainer-30-27", "item-36-23", "trainer-30-4",
        "trainer-12-16", "item-2-2", "trainer-5-6"
    ),
    "MtMoonB2F": ("exit-15-27", "exit-25-9", "exit-21-17"),
    # 1F is three sealed stretches, not one floor. The north mouth's holds the Pokémaniac and the
    # ladder down; the middle pocket is reached only by climbing back up from B1F, entered by one
    # of its ladders and left by the other; the southern stretch owns the mouth to Lavender. Rock
    # is no barrier to the flood, which walks between them and hands the middle pocket's Hikers to
    # whichever door they sit nearest, so every doorway of the crossing is named, and the
    # Pokémaniac with them: the walk meets him before it has left the first stretch.
    "RockTunnel1F": ("exit-15-3", "trainer-23-8", "exit-5-3", "exit-17-11", "exit-37-17",
                     "exit-15-33"),
    # Crossed twice, with the climb into 1F's middle pocket between the halves: in at the
    # southeast ladder, west along the bottom, up the middle and back east to the ladder under
    # that pocket, then down its other ladder and west again for the top-left corner. The flood
    # walks the rock, so it sorts that loop by how near the door each trainer ends up; the turns
    # are named instead.
    "RockTunnelB1F": ("exit-33-25", "trainer-14-28", "trainer-20-21", "trainer-30-10",
                      "exit-23-11"),
    # In off the street at the bottom of the room, so the coin sweep runs from the door. The floor
    # is open carpet with the machines as islands, so the flood orders the twelve piles on its own.
    "GameCorner": ("exit-15-17",),
    # Four floors walked in seven visits, and every floor is a case the flood cannot see. Three of
    # them are spin-tile mazes: an arrow tile is plain floor to the shipped collision, so the flood
    # strolls across a room the player can only cross by being fired at a wall and bouncing off a
    # stop tile. Every pin is named for that reason, in the order the walk reaches it.
    #
    # B1F is three rooms with no way between them on foot, though the flood joins two of them by
    # walking through the gate the last Rocket opens. Off the Game Corner stairs you take the
    # plant corridor's hidden PP Up, the Rocket on the west and the Escape Rope in the room under
    # him, then the one on the east; the southwest room is only ever entered by climbing back up
    # from B2F; and the last Rocket is met stepping out of the lift.
    "RocketHideoutB1F": (
        "exit-21-2", "hidden-21-15", "trainer-12-6", "item-11-14", "trainer-26-8",
        "exit-21-24", "trainer-15-25", "trainer-18-17", "item-9-17",
        "exit-24-19", "trainer-28-18"
    ),
    # Crossed three times. The first pass only loops round to the Rocket and drops to B3F; the west
    # maze is run on the way back up, and its four balls come off the arrows in an order no
    # straight line explains, the Moon Stone in the far corner first and the Nugget by the north
    # wall after; the last pass is the walk from the B1F stairs to the lift. Both closing doorways
    # are named so the drawn route covers the whole visit, not just as far as the last ball.
    "RocketHideoutB2F": ("exit-27-8", "trainer-20-12", "exit-21-8",
                         "item-1-11", "item-16-8", "item-6-12", "item-3-21",
                         "exit-21-22", "exit-24-19"),
    # In at the northeast stairs: the Rocket below them, the TM and the Nugget buried beside it
    # down the east wall, then back past the stairs into the maze for the Rare Candy and out west
    # to the second Rocket. The stairs are named twice because the floor is crossed twice: the
    # climb back up from B4F is its own ride through the maze, and the guide draws it.
    "RocketHideoutB3F": ("exit-25-6", "trainer-26-12", "item-26-17", "hidden-27-17",
                         "item-20-14", "trainer-10-22", "exit-19-18", "exit-25-6"),
    # Also crossed twice, and the second visit arrives by lift on the far side of a gate. The
    # first sweeps the west wing for the Lift Key; the second comes out of the lift for the Iron
    # and Giovanni's room.
    "RocketHideoutB4F": (
        "exit-19-10", "item-10-12", "item-9-4", "trainer-11-2", "item-10-2",
        "exit-24-15", "item-12-20", "hidden-25-1", "trainer-25-3", "item-25-2"
    ),
    # Up from 2F on the west stairs. Every tower floor is a ring of gravestone rows walked as a
    # lap, so plain distance from the door reads most of them backwards. Here the lap goes north
    # first, to the Channeler standing under the Escape Rope, then all the way down to the one on
    # the bottom row and back up to the last before the east stairs out.
    "PokemonTower3F": ("exit-3-9", "trainer-12-3", "trainer-10-13", "trainer-9-8"),
    # In from 3F on the east stairs, and the two Channelers waiting on the left of the doorway come
    # before the balls: the Elixir mid-floor, the Awakening one row west of it, then back to that
    # column and down into the notch on the south edge for the HP Up. The last Channeler stands
    # over by the west stairs out, so she letters after all three.
    "PokemonTower4F": ("exit-18-9", "trainer-15-7", "trainer-14-12",
                       "item-12-10", "item-9-10", "item-12-16", "trainer-5-10"),
    "PokemonTower5F": ("exit-3-9",),
    # In from 5F on the east stairs. The X Accuracy is a short drop south off the first Channeler,
    # so it is picked up long before the Rare Candy: that one sits over on the west side, reached
    # by going up over the top of the floor and back down, and its ball plugs the only gap through
    # to the stairs down. Distance from the door alone hands them over the other way round.
    "PokemonTower6F": ("exit-18-9", "trainer-12-10", "item-14-14",
                       "trainer-16-5", "trainer-9-5", "item-6-8"),
    "PokemonMansion1F": ("exit-4-27", "item-18-21", "hidden-8-16", "item-14-3"),
    "PokemonMansion3F": ("exit-7-10", "item-25-5", "item-1-16", "hidden-1-9"),
    "PokemonMansionB1F": (
        "exit-23-22", "item-19-25", "item-1-22", "item-5-13", "hidden-1-9", "item-5-4", "item-10-2"
    ),
    "SilphCo2F": ("exit-24-0",),
    "SilphCo3F": ("exit-26-0",),
    "SilphCo4F": ("exit-24-0", "item-4-7", "item-5-8", "item-3-9"),
    "SilphCo5F": ("exit-26-0",),
    "SilphCo6F": ("exit-14-0",),
    "SilphCo7F": ("exit-22-0", "item-1-9", "item-24-11"),
    "SilphCo8F": ("exit-14-0",),
    "SilphCo9F": ("exit-16-0",),
    "SilphCo10F": ("exit-8-0", "item-2-12", "item-4-14", "item-5-11"),
    "SilphCo11F": ("exit-9-0",),
    "PowerPlant": ("exit-4-35",),                   # the south door you Surf up to
    "UndergroundPathNorthSouth": ("exit-5-4",),     # down from the Route 5 house
    "UndergroundPathWestEast": ("exit-47-2",),      # down from the Route 8 house, walked west
    "CeruleanCave1F": ("exit-24-17", "item-29-16", "item-29-9", "hidden-18-7", "item-18-3", "item-7-11"),
    "CeruleanCave2F": ("exit-1-3",),
    "CeruleanCaveB1F": ("exit-3-6", "item-2-13", "item-3-13", "hidden-8-14", "item-15-3", "item-26-1"),
    # In at the southwest corner, along the bottom and up the first stair onto the mount, so the
    # Carbos is the first ball reached and the Egg Bomb west of it the second. Then the northwest
    # corner for the Max Potion, back east for the Full Restore and out of the North door. The
    # flood ranks the Egg Bomb first because it lies nearest the entrance as the crow flies, which
    # is a wall away from the stair the player actually climbs.
    "SafariZoneEast": ("exit-0-22", "item-20-13", "item-15-12", "item-3-7", "item-21-10"),
    # In from Area 1 on the east side and up the second stair, past the fences. TM40 is on the
    # climb and the Protein is beyond the top wall, reached through the one gap in it, so the walk
    # takes them in that order and comes back down for the southwest door.
    "SafariZoneNorth": ("exit-39-30", "item-19-7", "item-25-1"),
    # Walked twice, so it lists a doorway per visit. The first trip drops in from Area 2 at the top
    # and sweeps west along that band: Gold Teeth, TM32, the statue hiding the Revive, the Secret
    # House. The second comes back in from the Center once Surf is legal, and the east door reaches
    # the Max Revive in a few steps while the Max Potion is over the mount, which is the opposite of
    # the order one flood from the north hands out.
    "SafariZoneWest": ("exit-20-0", "item-19-7", "item-9-7", "hidden-6-5",
                       "exit-29-22", "item-18-18", "item-8-20"),
    "VictoryRoad1F": ("exit-8-17", "item-9-2", "item-11-0"),
    "VictoryRoad2F": (
        "exit-0-8", "hidden-5-2", "item-11-0", "item-9-11", "item-18-9", "hidden-26-7", "item-27-5"
    ),
    "VictoryRoad3F": ("exit-23-7",),
}

# A room you can only teleport into. Saffron's gym is eight sealed cells joined by warp pads, so
# walking from its front door reaches nobody at all and the pads have to count as steps of their
# own. Everywhere else they are left out on purpose: Silph Co is laced with one-way warp tiles the
# guide tells you to avoid, and letting the flood ride them would rank a trainer across the floor
# as if they were next door.
WARP_MAZES = frozenset({"SaffronGym"})

# Decks cleared by sweeping across the picture rather than by walking the corridor, and the side
# each sweep starts from. The S.S. Anne's cabins are rows of identical doors hung off one corridor,
# and the stairs land you partway along, so sweeping from one end saves walking the corridor twice.
# A deck is a composite of several maps with no single walk to measure, which is why this is a
# direction rather than a route, and it reaches inside a room as well: two trainers sharing one
# cabin have to come out the way the floor is cleared, not the way the map file lists them.
SWEEP_FROM = {"SSAnne1F": "right", "SSAnne2F": "left"}

# The pins whose letters are the order you reach them. Exits are not among them: a staircase wears
# one letter across the two floors it joins (markers.link_exit_keys), which is a different question
# from how far along a floor it sits.
WALKED = ("trainer", "item", "hidden")

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
    ids = ROUTES.get(label)
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
    if label not in ROUTES:
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
    if label not in ROUTES:
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
