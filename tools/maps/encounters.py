#!/usr/bin/env python3
"""What spawns on each map, read out of the game's own wild tables.

A walkthrough location is often several maps (Mt. Moon is 1F/B1F/B2F, the Safari Zone is four
areas), and Gen 1 gives every one of those maps its own encounter table. Those tables are not
small variations on each other: Sandshrew is on Mt. Moon 1F and nowhere else in the cave, Paras
is on B1F and B2F but not 1F, and Clefairy climbs from 1.2% on 1F to 10.5% on B2F. A single
per-location rate cannot say any of that, so this reads the tables per map.

  data/wild/maps/<Map>.asm     ten ordered slots, each `db <level>, <SPECIES>`, for grass (which
                               covers cave floors too) and for water (Surf).
  data/wild/probabilities.asm  how often each of the ten slots is chosen. The slots are weighted
                               51/51/39/25/25/25/13/13/11/3 out of 256, so a species' real rate is
                               the sum of the weights of every slot it holds, not 10% a slot.

The per-step encounter rate that `def_grass_wildmons` carries is how often *any* battle starts,
a property of the map rather than of a species, so it is reported per map and kept apart from
the per-species share.
"""
import re
from functools import cache

import locations
import sources

SLOT_TOTAL = 256

# GenerateRandomFishingEncounter (engine/items/super_rod.asm) walks four slots, taking one when a
# random byte falls under $66 / $b2 / $e5 and the fourth otherwise. Those cut points are 102, 76,
# 51 and 27 of 256, so the Super Rod is not a flat quarter each.
SUPER_ROD_SLOTS = (102, 76, 51, 27)

# ItemUseOldRod hands over a fixed Magikarp; ItemUseGoodRod rerolls until it bites and then picks
# evenly between the two GoodRodMons. Neither reads a per-map table, so both are the same
# everywhere there is water to cast into.
OLD_ROD_MON = ("MAGIKARP", 5)

ROD_KINDS = ("old_rod", "good_rod", "super_rod")


@cache
def slot_weights(root_str):
    """The chance of each of the ten wild slots, straight from WildMonEncounterSlotChances."""
    text = sources.read_data(root_str, "data/wild/probabilities.asm")
    weights = [int(n) for n in re.findall(r"^\s*wild_chance\s+(\d+)", text, re.M)]
    if sum(weights) != SLOT_TOTAL:
        raise ValueError(f"wild slot chances sum to {sum(weights)}, not {SLOT_TOTAL}")
    return weights


def _slots(text, kind):
    """The ten (level, species) slots of one table, or [] when the map has none of that kind."""
    block = re.search(rf"def_{kind}_wildmons\s+(\d+)(.*?)end_{kind}_wildmons", text, re.S)
    if not block or int(block.group(1)) == 0:
        return 0, []
    return int(block.group(1)), re.findall(r"db\s+(\d+),\s*(\w+)", block.group(2))


def table_for(root_str, map_label, kind):
    """One map's encounter table for `grass` or `water`, aggregated per species.

    Returns None when the map has no table of that kind, which is the common case: most
    buildings and every Rocket Hideout floor have neither."""
    text = sources.read_data(root_str, f"data/wild/maps/{map_label}.asm", missing_ok=True)
    if text is None:
        return None
    step_rate, slots = _slots(text, kind)
    if not slots:
        return None

    weights = slot_weights(root_str)
    found = {}
    for index, (level, species) in enumerate(slots):
        entry = found.setdefault(species, {"weight": 0, "levels": []})
        entry["weight"] += weights[index]
        entry["levels"].append(int(level))
    return {"step_rate": step_rate, "mons": found}


@cache
def good_rod_mons(root_str):
    """The two species the Good Rod alternates between, read rather than assumed."""
    text = sources.read_data(root_str, "data/wild/good_rod.asm")
    return [(species, int(level))
            for level, species in re.findall(r"db\s+(\d+),\s*(\w+)", text)]


@cache
def super_rod_slots(root_str):
    """map const -> its four ordered (species, level) Super Rod slots."""
    text = sources.read_data(root_str, "data/wild/super_rod.asm")
    out = {}
    for line in re.findall(r"^\s*db\s+([A-Z0-9_]+(?:,\s*\w+,\s*\d+){4})\s*$", text, re.M):
        parts = [p.strip() for p in line.split(",")]
        out[parts[0]] = [(parts[i], int(parts[i + 1])) for i in range(1, len(parts), 2)]
    return out


def _weighted(pairs, weights):
    """Fold (species, level) slots into per-species weight and level band."""
    found = {}
    for (species, level), weight in zip(pairs, weights, strict=True):
        entry = found.setdefault(species, {"weight": 0, "levels": []})
        entry["weight"] += weight
        entry["levels"].append(level)
    return found


def rod_table(root_str, map_const, kind):
    """One map's table for a rod, or None when that rod finds nothing there.

    The Old and Good Rods carry no map table at all, so they are offered wherever the map has
    water to fish; the Super Rod bites only on the maps listed in SuperRodFishingSlots."""
    if kind == "super_rod":
        slots = super_rod_slots(root_str).get(map_const)
        return None if slots is None else _weighted(slots, SUPER_ROD_SLOTS)
    if kind == "old_rod":
        return _weighted([OLD_ROD_MON], [SLOT_TOTAL])
    even = SLOT_TOTAL // len(good_rod_mons(root_str))
    return _weighted(good_rod_mons(root_str), [even] * len(good_rod_mons(root_str)))


def _mon_rows(root_str, table):
    """Species rows carry the dex number the Rails side keys on, zero-padded the way the
    walkthrough writes it ("041"), so no lookup table is duplicated there."""
    dex = sources.parse_dex_numbers(root_str)
    rows = []
    for species, entry in table["mons"].items():
        rows.append({"species": species,
                     "dex": f"{dex[species]:03d}",
                     "rate": round(entry["weight"] * 100 / SLOT_TOTAL, 1),
                     "min_level": min(entry["levels"]),
                     "max_level": max(entry["levels"]),
                     "slots": len(entry["levels"])})
    return sorted(rows, key=lambda row: (-row["rate"], row["species"]))


def fishable(root_str, map_label, map_const):
    """Whether a rod has anywhere to cast on this map.

    The game gates the Old and Good Rods on facing a water tile rather than on a table, which no
    single file records. Two witnesses stand in for it, and between them they cover every place
    the walkthrough sends you fishing: a surfable water table, or a Super Rod entry (the game
    would not list slots for a map you cannot fish)."""
    return (table_for(root_str, map_label, "water") is not None
            or map_const in super_rod_slots(root_str))


def build_encounters(root_str):
    """slug -> ordered list of one entry per map and method that finds anything.

    A location whose maps all come up empty is left out entirely rather than carried as an empty
    list, so the Rails side can treat presence as "this place has wild Pokemon"."""
    consts = {label: const for label, (const, _tileset) in sources.parse_headers(root_str).items()}
    out = {}
    for slug, maps in locations.location_maps().items():
        places = []
        for map_label, floor, _parent in maps:
            map_const = consts.get(map_label)
            for kind in ("grass", "water"):
                table = table_for(root_str, map_label, kind)
                if table is None:
                    continue
                places.append({"map": map_label, "floor": floor, "kind": kind,
                               "step_rate": table["step_rate"],
                               "mons": _mon_rows(root_str, table)})
            if not fishable(root_str, map_label, map_const):
                continue
            for kind in ROD_KINDS:
                mons = rod_table(root_str, map_const, kind)
                if not mons:
                    continue
                places.append({"map": map_label, "floor": floor, "kind": kind,
                               "step_rate": None,
                               "mons": _mon_rows(root_str, {"mons": mons})})
        if places:
            out[slug] = places
    return out
