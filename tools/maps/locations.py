#!/usr/bin/env python3
"""Which pokeyellow maps make up each walkthrough location.

Shared by build.py (which renders one area map per entry) and roster.py (which reads the
trainers standing on them), so it lives apart from both to keep those two from importing
each other.
"""

# slug -> ordered [(map_label, floor_label, parent_map_const_or_None)]; parent is only needed for
# interiors that aren't cavern/cemetery (they inherit a town palette).
_SIMPLE = {
    "pallet-town": "PalletTown", "route-1": "Route1", "viridian-city": "ViridianCity",
    "route-22": "Route22", "route-2": "Route2", "viridian-forest": "ViridianForest",
    "route-3": "Route3", "route-4": "Route4", "route-24": "Route24", "route-25": "Route25",
    "route-5": "Route5", "route-6": "Route6", "route-11": "Route11", "route-9": "Route9",
    "route-10": "Route10", "lavender-town": "LavenderTown", "route-8": "Route8", "route-7": "Route7",
    "route-12": "Route12", "route-13": "Route13", "route-14": "Route14", "route-15": "Route15",
    "route-16": "Route16", "route-17": "Route17", "route-18": "Route18", "route-19": "Route19",
    "route-20": "Route20", "power-plant": "PowerPlant", "route-21": "Route21", "route-23": "Route23",
    "indigo-plateau": "IndigoPlateau", "digletts-cave": "DiglettsCave",
}
_GYM_CITIES = {
    "pewter-city": ("PewterCity", "PewterGym", "PEWTER_CITY"),
    "cerulean-city": ("CeruleanCity", "CeruleanGym", "CERULEAN_CITY"),
    "vermilion-city": ("VermilionCity", "VermilionGym", "VERMILION_CITY"),
    "celadon-city": ("CeladonCity", "CeladonGym", "CELADON_CITY"),
    "fuchsia-city": ("FuchsiaCity", "FuchsiaGym", "FUCHSIA_CITY"),
    "saffron-city": ("SaffronCity", "SaffronGym", "SAFFRON_CITY"),
    "cinnabar-island": ("CinnabarIsland", "CinnabarGym", "CINNABAR_ISLAND"),
}


def _floors(base, labels, parent=None):
    return [(f"{base}{s}", s, parent) for s in labels]


_DUNGEONS = {
    "mt-moon": _floors("MtMoon", ["1F", "B1F", "B2F"]),
    "rock-tunnel": _floors("RockTunnel", ["1F", "B1F"]),
    "seafoam-islands": _floors("SeafoamIslands", ["1F", "B1F", "B2F", "B3F", "B4F"]),
    "cerulean-cave": _floors("CeruleanCave", ["1F", "2F", "B1F"]),
    "victory-road": _floors("VictoryRoad", ["1F", "2F", "3F"]),
    "pokemon-tower": _floors("PokemonTower", ["1F", "2F", "3F", "4F", "5F", "6F", "7F"]),
    "silph-co": _floors("SilphCo",
                        ["1F", "2F", "3F", "4F", "5F", "6F", "7F", "8F", "9F", "10F", "11F"],
                        "SAFFRON_CITY"),
    "rocket-hideout": _floors("RocketHideout", ["B1F", "B2F", "B3F", "B4F"], "CELADON_CITY"),
    "pokemon-mansion": _floors("PokemonMansion", ["1F", "2F", "3F", "B1F"], "CINNABAR_ISLAND"),
    # One entry per deck; the cabins, kitchen and bow are drawn into the deck they open off (see
    # _ATTACHED below and decks.py), not listed here as floors of their own.
    # Decks in the order the guide walks them, not the order the ship is stacked: you board on 1F
    # and go straight below, so B1F comes second and the two upper decks follow.
    "ss-anne": [("SSAnne1F", "1F", "VERMILION_CITY"),
                ("SSAnneB1F", "B1F", "VERMILION_CITY"),
                ("SSAnne2F", "2F", "VERMILION_CITY"),
                ("SSAnne3F", "3F", "VERMILION_CITY")],
    "underground-path": [("UndergroundPathNorthSouth", "", None)],
    "underground-path-west-east": [("UndergroundPathWestEast", "", None)],
    "safari-zone": [("SafariZoneCenter", "Center", None), ("SafariZoneEast", "East", None),
                    ("SafariZoneNorth", "North", None), ("SafariZoneWest", "West", None)],
    "viridian-gym": [("ViridianGym", "", "VIRIDIAN_CITY")],
}

# Maps drawn into another map's image rather than as a floor of their own: {corridor: [(map,
# floor label)]}. The game keeps a deck's cabins on one shared map (SS_ANNE_1F_ROOMS is all six 1F
# cabins in a 3x2 grid), which made the ship a corridor of identical doors beside a grid of
# identical cabins, and left the reader to pair them off by letter. decks.py crops each room out
# and hangs it under its own door instead. The floor label rides along because a trainer's "where"
# shot is still named after the map it really stands on.
_ATTACHED = {
    "SSAnne1F": [("SSAnne1FRooms", "1F Rooms"), ("SSAnneKitchen", "Kitchen")],
    "SSAnne2F": [("SSAnne2FRooms", "2F Rooms")],
    "SSAnne3F": [("SSAnneBow", "Bow")],
    "SSAnneB1F": [("SSAnneB1FRooms", "B1F Rooms")],
}


def attached(map_label):
    """The maps drawn into this one's image, as [(label, floor label)]; empty for a plain map."""
    return _ATTACHED.get(map_label, [])


_EXTRA_TRAINER_MAPS = {
    # The three *Rooms maps and the bow moved into _DUNGEONS above. They must not stay here too:
    # roster.py walks this list separately from location_maps, so a map in both is counted twice.
    "saffron-city": [("FightingDojo", "SAFFRON_CITY", "")],
    # The Game Corner's lone Rocket guards the stairs down, so he rosters with the hideout he is
    # standing on rather than with the town the arcade happens to sit in. He is named by the room
    # instead of a floor, because every other card on that page reads B1F to B4F and he is upstairs.
    "rocket-hideout": [("GameCorner", "CELADON_CITY", "Game Corner")],
}


# Maps a location owns beyond its town and gym. The Vermilion dock is its own map with its own
# Super Rod slots (Staryu and Shellder, neither of which the city's own water gives up), so it has
# to be drawn for those to have anywhere to hang.
_ANNEXES = {
    "vermilion-city": [("VermilionDock", "Dock", "VERMILION_CITY")],
}


def location_maps():
    out = {}
    for slug, label in _SIMPLE.items():
        out[slug] = [(label, "", None)]
    for slug, (town, gym, parent) in _GYM_CITIES.items():
        out[slug] = [(town, "", None), (gym, "Gym", parent)] + _ANNEXES.get(slug, [])
    out.update(_DUNGEONS)
    return out


def extra_trainer_maps(slug):
    """(map label, palette parent, floor label) for each map a location rosters but does not draw."""
    return _EXTRA_TRAINER_MAPS.get(slug, [])


def image_name(slug, floor):
    return slug if not floor else f"{slug}-{floor.lower().replace(' ', '-')}"
