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
FOCUS_CELLS = 1

FACINGS = {"DOWN": (0, 1), "UP": (0, -1), "LEFT": (-1, 0), "RIGHT": (1, 0)}
DEFAULT_FACING = "DOWN"
OPPOSITE = {"DOWN": "UP", "UP": "DOWN", "LEFT": "RIGHT", "RIGHT": "LEFT"}


def facing_of(obj):
    return obj["direction"] if obj["direction"] in FACINGS else DEFAULT_FACING


def scene_name(area, obj):
    """Stable and unique: the area's image name plus the trainer's own cell, which is game data
    and matches the marker id the page already uses."""
    return f"{area}-trainer-{obj['grid'][0]}-{obj['grid'][1]}"


def where_spec(map_label, parent, obj, name):
    """The 'where' shot: the hero two cells in front of the trainer, both facing each other, with
    the trainer flashing the '!' it shows on spotting you."""
    facing = facing_of(obj)
    step_x, step_y = FACINGS[facing]
    grid = obj["grid"]
    spec = {
        "type": "screen", "name": name, "map": map_label,
        "player": [grid[0] + step_x * PLAYER_CELLS, grid[1] + step_y * PLAYER_CELLS],
        "player_dir": OPPOSITE[facing],
        "focus": [grid[0] + step_x * FOCUS_CELLS, grid[1] + step_y * FOCUS_CELLS],
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
                specs.append(where_spec(label, parent, obj, name))
                entries.append(entry_for(root_str, area, floor, obj, key, name))

        for label, parent in locations.extra_trainer_maps(slug):
            area = locations.image_name(slug, label.lower())
            for obj in _map_trainers(root_str, label):
                name = scene_name(area, obj)
                specs.append(where_spec(label, parent, obj, name))
                entries.append(entry_for(root_str, area, "", obj, None, name))

        if entries:
            roster[slug] = entries

    return roster, specs
