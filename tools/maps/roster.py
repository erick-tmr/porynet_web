#!/usr/bin/env python3
"""Every trainer the walkthrough can send you into, read out of the game.

A trainer card needs a class, a team, a prize and a screenshot of where the fight happens, and
all four are in the disassembly: the map object says which class and which party, parties.asm
holds the team, pic_pointers_money.asm the prize, and the object's own cell and facing frame the
shot. So the roster is generated rather than typed, and it cannot drift from the game.

Two things it deliberately does not carry: the sprite basename and the display name of the
class. Those are product decisions and stay in the Rails model.
"""
import locations
import markers
import sources

PLAYER_CELLS = 2

FACINGS = {"DOWN": (0, 1), "UP": (0, -1), "LEFT": (-1, 0), "RIGHT": (1, 0)}
DEFAULT_FACING = "DOWN"
OPPOSITE = {"DOWN": "UP", "UP": "DOWN", "LEFT": "RIGHT", "RIGHT": "LEFT"}


def facing_of(obj):
    return obj["direction"] if obj["direction"] in FACINGS else DEFAULT_FACING


def scene_name(area, obj):
    """Stable and unique: the area's image name plus the trainer's own cell, which is game data
    and matches the marker id the page already uses."""
    return f"{area}-trainer-{obj['grid'][0]}-{obj['grid'][1]}"


def hero_cell(root_str, map_label, grid, step):
    """Where the hero stands to face the trainer: never a tile it could not actually stand on.

    First choice is its line of sight, two cells in front for a clean framing, then one nearer,
    then one farther, so a tree or wall the trainer spots you through is skipped. Dry land wins
    over water at every step, so a gym swimmer's shot stands the hero on the poolside rather than
    floating mid-pool; open water is still allowed (a route swimmer is fought while surfing). A
    trainer boxed against the wall it faces has nothing in front at all (a Game Corner Rocket), so
    the last resort is the nearest standable tile in any direction: off a solid tile beats in-frame."""
    const, tileset = sources.parse_headers(root_str)[map_label]
    _idx, w_blocks, h_blocks = sources.parse_map_constants(root_str)[0][const]
    w_cells, h_cells = w_blocks * 2, h_blocks * 2

    def on(predicate, x, y):
        return 0 <= x < w_cells and 0 <= y < h_cells and \
            predicate(root_str, map_label, tileset, w_blocks, (x, y))

    line = [(grid[0] + step[0] * d, grid[1] + step[1] * d)
            for d in (PLAYER_CELLS, PLAYER_CELLS - 1, PLAYER_CELLS + 1)]
    for predicate in (markers.cell_is_land, markers.cell_is_walkable):
        for x, y in line:
            if on(predicate, x, y):
                return [x, y]
        for radius in range(1, max(w_cells, h_cells)):
            ring = [(grid[0] + dx, grid[1] + dy)
                    for dx in range(-radius, radius + 1) for dy in range(-radius, radius + 1)
                    if max(abs(dx), abs(dy)) == radius and on(predicate, grid[0] + dx, grid[1] + dy)]
            if ring:
                return list(min(ring, key=lambda c: (abs(c[0] - grid[0]) + abs(c[1] - grid[1]), c)))

    return [grid[0] + step[0] * PLAYER_CELLS, grid[1] + step[1] * PLAYER_CELLS]


def where_spec(root_str, map_label, parent, obj, name):
    """The 'where' shot: the hero on a walkable tile in front of the trainer, both facing each
    other, with the trainer flashing the '!' it shows on spotting you. The camera sits midway
    between them so both stay framed however near the hero ends up.

    `auto_npcs` keeps the map's other real people in frame as landmarks (only the spotting trainer
    flashes the '!'), so a gym trainer's shot still shows the leader standing behind them the way
    the room really looks from that angle."""
    facing = facing_of(obj)
    step = FACINGS[facing]
    grid = obj["grid"]
    player = hero_cell(root_str, map_label, grid, step)
    spec = {
        "type": "screen", "name": name, "map": map_label,
        "player": player,
        "player_dir": OPPOSITE[facing],
        "focus": [(grid[0] + player[0]) // 2, (grid[1] + player[1]) // 2],
        "auto_npcs": True,
        "sprites": [{"sprite": obj["sprite_const"], "grid": list(grid),
                     "dir": facing, "emote": "shock"}],
    }
    if parent:
        spec["parent"] = parent
    return spec


def team_of(root_str, obj):
    dex = sources.parse_dex_numbers(root_str)
    party = sources.trainer_party(root_str, obj["opp_class"], obj["party"])
    return [{"dex": f"{dex[species]:03d}", "lvl": level} for level, species in party]


def entry_for(root_str, area, floor, obj, key, scene):
    party = sources.trainer_party(root_str, obj["opp_class"], obj["party"])
    return {
        "map": area, "floor": floor, "marker": f"trainer-{obj['grid'][0]}-{obj['grid'][1]}",
        "key": key, "opp": f"{obj['opp_class']}:{obj['party']}", "cls": obj["opp_class"],
        "reward": sources.trainer_reward(root_str, obj["opp_class"], party),
        "team": team_of(root_str, obj),
        "where": f"walkthrough/yellow/scenes/{scene}.png",
    }


def _map_trainers(root_str, map_label):
    return [o for o in sources.parse_object_events(root_str, map_label, include_battlers=True)
            if o["kind"] == "trainer"]


def build_roster(root_str):
    """Return ({slug: [entry]}, [where-scene spec]).

    Entries come out in the order the page shows them: floor by floor, and within a floor in the
    order the map file declares them, which is the order markers.key_letters lettered the pins.
    A location's extra maps come last; they have no drawn map, so their cards carry no letter."""
    headers = sources.parse_headers(root_str)
    roster, specs = {}, []

    for slug, maps in sorted(locations.location_maps().items()):
        entries = []
        for label, floor, parent in maps:
            if label not in headers:
                continue
            area = locations.image_name(slug, floor)
            for index, obj in enumerate(_map_trainers(root_str, label)):
                key = None if floor == "Gym" else markers.key_letters(index)
                name = scene_name(area, obj)
                specs.append(where_spec(root_str, label, parent, obj, name))
                entries.append(entry_for(root_str, area, floor, obj, key, name))

        for label, parent in locations.extra_trainer_maps(slug):
            area = locations.image_name(slug, label.lower())
            for obj in _map_trainers(root_str, label):
                name = scene_name(area, obj)
                specs.append(where_spec(root_str, label, parent, obj, name))
                entries.append(entry_for(root_str, area, "", obj, None, name))

        if entries:
            roster[slug] = entries

    return roster, specs
