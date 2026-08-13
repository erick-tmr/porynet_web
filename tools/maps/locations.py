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
    # The cabin sub-maps are rendered as their own floors, not folded into the deck above them:
    # six items live only in the cabins, and an unrendered map can carry no marker for them. Each
    # deck is followed by the rooms you reach from it, so a reader walking 1F does not have to
    # scroll past every other deck to find the 1F cabins. The kitchen hangs off 1F the same way,
    # and is here because a Great Ball is buried in its last bin.
    "ss-anne": [("SSAnne1F", "1F", "VERMILION_CITY"),
                ("SSAnne1FRooms", "1F Rooms", "VERMILION_CITY"),
                ("SSAnneKitchen", "Kitchen", "VERMILION_CITY"),
                ("SSAnne2F", "2F", "VERMILION_CITY"),
                ("SSAnne2FRooms", "2F Rooms", "VERMILION_CITY"),
                ("SSAnne3F", "3F", "VERMILION_CITY"),
                ("SSAnneBow", "Bow", "VERMILION_CITY"),
                ("SSAnneB1F", "B1F", "VERMILION_CITY"),
                ("SSAnneB1FRooms", "B1F Rooms", "VERMILION_CITY")],
    "underground-path": [("UndergroundPathNorthSouth", "", None)],
    "safari-zone": [("SafariZoneCenter", "Center", None), ("SafariZoneEast", "East", None),
                    ("SafariZoneNorth", "North", None), ("SafariZoneWest", "West", None)],
    "viridian-gym": [("ViridianGym", "", "VIRIDIAN_CITY")],
}

_EXTRA_TRAINER_MAPS = {
    # The three *Rooms maps and the bow moved into _DUNGEONS above. They must not stay here too:
    # roster.py walks this list separately from location_maps, so a map in both is counted twice.
    "saffron-city": [("FightingDojo", "SAFFRON_CITY")],
    "celadon-city": [("GameCorner", "CELADON_CITY")],
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
    return _EXTRA_TRAINER_MAPS.get(slug, [])


def image_name(slug, floor):
    return slug if not floor else f"{slug}-{floor.lower().replace(' ', '-')}"
