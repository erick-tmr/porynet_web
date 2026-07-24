#!/usr/bin/env python3
"""Read what waits behind each door: the facts pokeyellow records about a destination map.

An exit marker on an area map points at a map const (OAKS_LAB, CELADON_GYM,
CELADON_MANSION_ROOF_HOUSE). This module turns that const into the facts the game itself
states about the place, so the marker's hint can say "free Eevee at Lv 25 inside" instead of
"a door inside the map". Nothing here is authored; every field is parsed from the disassembly:

  kind       what sort of place it is, read off the map const with the header's tileset
             (data/maps/headers/<Map>.asm) as the fallback. The const is the better witness:
             Oak's Lab and the Fighting Dojo share the DOJO tileset, Saffron Gym is drawn with
             the FACILITY one because of its teleport pads.
  stock      the clerk's `script_mart` line in data/items/marts.asm, matched to the map by the
             script file that references the clerk text.
  gym        the badge bit and TM the gym script hands out, plus the leader (the first trainer
             object on the map) and the type their party leans on.
  gift_mon   `GivePokemon` in the map's script or text, either `lb bc, <SPECIES>, <level>` or
             the two-step form the Fighting Dojo uses (`ld a, <SPECIES>` + `DisplayPokedex`).
  gift_item  `GiveItem` after `lb bc, <ITEM>, <qty>`: the S.S. Ticket, the rods, the Poké Flute.
  trainers   / items: the map's own object events, the same list the maps are drawn from.
"""
import collections
import re
from functools import cache

import sources

# map const word -> the kind of place the walkthrough copy talks about, first match wins
KIND_BY_WORD = (
    ("HALL_OF_FAME", "league"), ("CHAMPIONS_ROOM", "league"), ("LORELEIS_ROOM", "league"),
    ("BRUNOS_ROOM", "league"), ("AGATHAS_ROOM", "league"), ("LANCES_ROOM", "league"),
    ("INDIGO_PLATEAU", "league"), ("HOTEL", "hotel"),
    ("POKECENTER", "center"), ("MART", "mart"), ("GYM", "gym"), ("LAB", "lab"),
    ("HOUSE", "house"), ("GATE", "gate"), ("DOJO", "dojo"), ("POKEMON_TOWER", "tower"),
    ("SS_ANNE", "ship"), ("CAVE", "dungeon"), ("TUNNEL", "dungeon"), ("MT_MOON", "dungeon"),
    ("FOREST", "dungeon"), ("SEAFOAM", "dungeon"), ("VICTORY_ROAD", "dungeon"),
)
KIND_BY_TILESET = {
    "POKECENTER": "center", "MART": "mart", "GYM": "gym", "LAB": "lab",
    "HOUSE": "house", "REDS_HOUSE_1": "house", "REDS_HOUSE_2": "house", "BEACH_HOUSE": "house",
    "GATE": "gate", "FOREST_GATE": "gate",
    "CAVERN": "dungeon", "FOREST": "dungeon", "UNDERGROUND": "dungeon",
    "CEMETERY": "tower", "SHIP": "ship", "SHIP_PORT": "ship", "DOJO": "dojo",
    "OVERWORLD": "outdoor",
}
DEFAULT_KIND = "facility"

# names.asm spells the leaders the way the game's text does
LEADER_FIXUPS = {"LT.SURGE": "Lt. Surge"}

# the move behind the const, where the const carries a disambiguating suffix
TM_MOVE_FIXUPS = {"TM_PSYCHIC_M": "Psychic"}


def place_kind(const, tileset):
    for word, kind in KIND_BY_WORD:
        if word in const:
            return kind
    return KIND_BY_TILESET.get(tileset, DEFAULT_KIND)

_GIVE_MON = re.compile(r"lb\s+bc,\s*([A-Z0-9_]+),\s*(\d+)[^\n]*\n(?:[^\n]*\n){0,4}?\s*call GivePokemon")
_CHOSEN_MON = re.compile(r"ld\s+a,\s*([A-Z0-9_]+)\s*\n\s*call DisplayPokedex"
                         r"(?:[^\n]*\n){0,20}?\s*ld\s+c,\s*(\d+)\s*\n\s*ld\s+b,\s*a\s*\n\s*call GivePokemon"
                         r"|ld\s+a,\s*([A-Z0-9_]+)\s*\n\s*call DisplayPokedex"
                         r"(?:[^\n]*\n){0,20}?\s*ld\s+b,\s*a\s*\n\s*ld\s+c,\s*(\d+)\s*\n\s*call GivePokemon")
_GIVE_ITEM = re.compile(r"lb\s+bc,\s*([A-Z0-9_]+),\s*(\d+)[^\n]*\n(?:[^\n]*\n){0,2}?\s*call GiveItem")
_MART = re.compile(r"^(\w+)::?\s*\n\s*script_mart\s+(.+)$", re.M)
_WALLET_LOOKBACK = 600
_ADD_TM = re.compile(r"^\s*add_tm\s+(\w+)", re.M)
_PRICE = re.compile(r"^\s*bcd3\s+(\d+)\s*;\s*(\w+)", re.M)
_TM_PRICE = re.compile(r"^\s*nybble\s+(\d+)\s*;\s*TM(\d+)", re.M)
_MOVE = re.compile(r"^\s*move\s+(\w+),\s*\w+,\s*\d+,\s*(\w+),", re.M)

# Vending drinks are never in a clerk's `script_mart`, but the Celadon rooftop sells them, so
# the catalog carries them alongside the mart stock (their prices are in the same prices.asm).
_EXTRA_ITEMS = ("FRESH_WATER", "SODA_POP", "LEMONADE")


@cache
def _consts_by_label(root_str):
    return {label: const for label, (const, _tileset) in sources.parse_headers(root_str).items()}


def _map_const(root_str, file_stem):
    """A script/text file maps to one map const. Yellow's `_2` files hold the second half of a
    map's scripts (BillsHouse_2.asm), so they answer to the same const."""
    return _consts_by_label(root_str).get(re.sub(r"_\d+$", "", file_stem))


@cache
def parse_tm_numbers(root_str):
    """Return {TM_<MOVE>: number}. item_constants.asm lists the TMs in order from TM01."""
    moves = _ADD_TM.findall(sources._read(root_str, "constants/item_constants.asm"))
    return {f"TM_{move}": number for number, move in enumerate(moves, start=1)}


def tm_display_name(root_str, const):
    """TM_MEGA_DRAIN -> 'TM21 Mega Drain'; anything else keeps its plain item name."""
    number = parse_tm_numbers(root_str).get(const)
    if number is None:
        return sources.item_display_name(const)
    move = TM_MOVE_FIXUPS.get(const, const[len("TM_"):].replace("_", " ").title())
    return f"TM{number:02d} {move}"


@cache
def parse_prices(root_str):
    """Return {item const: price} from data/items/prices.asm (`bcd3 <price> ; <CONST>`)."""
    return {const: int(price)
            for price, const in _PRICE.findall(sources._read(root_str, "data/items/prices.asm"))}


@cache
def parse_tm_prices(root_str):
    """Return {TM number: price}. data/items/tm_prices.asm lists a nybble per TM, in thousands."""
    return {int(number): int(nybble) * 1000
            for nybble, number in _TM_PRICE.findall(sources._read(root_str, "data/items/tm_prices.asm"))}


@cache
def parse_move_types(root_str):
    """Return {move const: type slug}. PSYCHIC_TYPE -> 'psychic', so it names the TM's sprite."""
    return {move: kind.removesuffix("_TYPE").lower()
            for move, kind in _MOVE.findall(sources._read(root_str, "data/moves/moves.asm"))}


def item_price(root_str, const):
    """The shop price of an item, 0 when it cannot be bought. TMs are priced by their number."""
    if const.startswith("TM_"):
        number = parse_tm_numbers(root_str).get(const)
        return parse_tm_prices(root_str).get(number, 0)
    return parse_prices(root_str).get(const, 0)


def build_item_catalog(root_str):
    """Return {display name: facts} for every item a mart, gift or vending machine offers, so the
    walkthrough can price and picture it. Keyed by the same display string that appears in a
    place's `stock`/`gift_item`, which is the join back to the catalog. Nothing here is authored:
    price from prices.asm/tm_prices.asm, the TM number from item_constants.asm, its move's type
    from moves.asm."""
    marts, gifts = parse_marts(root_str), parse_gifts(root_str)
    move_types = parse_move_types(root_str)
    catalog = {}

    def add(const, display):
        entry = {"const": const}
        if price := item_price(root_str, const):
            entry["price"] = price
        if const.startswith("TM_"):
            move = const[len("TM_"):]
            entry["tm"] = parse_tm_numbers(root_str).get(const)
            entry["move"] = TM_MOVE_FIXUPS.get(const, move.replace("_", " ").title())
            if kind := move_types.get(move):
                entry["type"] = kind
        catalog[display] = entry

    for consts in marts.values():
        for const in consts:
            add(const, sources.item_display_name(const))
    for gift in gifts.values():
        for const, _qty in gift.get("item", ()):
            add(const, tm_display_name(root_str, const))
    for const in _EXTRA_ITEMS:
        add(const, sources.item_display_name(const))
    return dict(sorted(catalog.items()))


@cache
def parse_marts(root_str):
    """Return {map_const: (item const, ...)}. The stock lives on the clerk's text symbol, which
    only the owning map's script file references, so the reference is the join."""
    stock = {symbol: tuple(i.strip() for i in items.split(","))
             for symbol, items in _MART.findall(sources._read(root_str, "data/items/marts.asm"))}
    out = {}
    for path in sorted((sources._root(root_str) / "scripts").glob("*.asm")):
        const = _map_const(root_str, path.stem)
        if const is None:
            continue
        text = path.read_text()
        for symbol, items in stock.items():
            if re.search(rf"\b{symbol}\b", text):
                out.setdefault(const, ())
                out[const] += items
    return out


@cache
def parse_gifts(root_str):
    """Return {map_const: {"mon": ((species, level), ...), "item": (item const, ...)}}."""
    species = set(sources.parse_dex_numbers(root_str))
    out = {}
    for folder in ("scripts", "text"):
        for path in sorted((sources._root(root_str) / folder).glob("*.asm")):
            const = _map_const(root_str, path.stem)
            if const is None:
                continue
            text = path.read_text()
            entry = out.setdefault(const, {"mon": (), "item": ()})
            entry["mon"] += _gift_mons(text, species)
            entry["item"] += tuple((item, int(qty)) for item, qty in _GIVE_ITEM.findall(text))
    return {const: entry for const, entry in out.items() if entry["mon"] or entry["item"]}


def _gift_mons(text, species):
    """Every Pokémon the map hands over, as (species, level, sold). The Mt. Moon Magikarp goes
    through the same GivePokemon call as a free Eevee, but its script weighs your wallet first
    (HasEnoughMoney), so the two are told apart by that check."""
    found = []
    for match in _GIVE_MON.finditer(text):
        found.append((match.group(1), int(match.group(2)), _is_sold(text, match.start())))
    for match in _CHOSEN_MON.finditer(text):
        name, level = match.group(1) or match.group(3), match.group(2) or match.group(4)
        found.append((name, int(level), _is_sold(text, match.start())))
    return tuple(dict.fromkeys(f for f in found if f[0] in species))


def _is_sold(text, offset):
    return "HasEnoughMoney" in text[max(0, offset - _WALLET_LOOKBACK):offset]


@cache
def parse_pokemon_types(root_str):
    """Return {species const: (type, ...)} from data/pokemon/base_stats/<name>.asm."""
    out = {}
    for path in sorted((sources._root(root_str) / "data/pokemon/base_stats").glob("*.asm")):
        match = re.search(r"^\s*db\s+(\w+),\s*(\w+)\s*;\s*type", path.read_text(), re.M)
        if match:
            out[path.stem.upper()] = tuple(dict.fromkeys(match.groups()))
    return out


def gym_facts(root_str, label, objects):
    """Badge, TM, leader and team types for a gym map, or None unless the map states all four.
    The leader is the map's first trainer object, which is how every gym lists them."""
    text = _script_text(root_str, label)
    badge = re.search(r"set BIT_(\w+)BADGE", text)
    tm = re.search(r"lb bc, (TM_\w+), 1", text)
    leader = next((o for o in objects if o["kind"] == "trainer"), None)
    if not (badge and tm and leader):
        return None
    name = sources.parse_trainer_classes(root_str)[leader["opp_class"]][1]
    return {"badge": badge.group(1).title(), "tm": tm_display_name(root_str, tm.group(1)),
            "leader": LEADER_FIXUPS.get(name, name.title()),
            "types": _party_types(root_str, leader)}


def _party_types(root_str, leader):
    """The types a leader's whole team shares: Brock fields nothing but Rock/Ground, Koga in
    Yellow nothing but Bug/Poison. A team with no type in common falls back to its commonest,
    so the answer is always what you have to prepare for."""
    party = sources.trainer_party(root_str, leader["opp_class"], leader["party"])
    types = parse_pokemon_types(root_str)
    per_mon = [types.get(mon, ()) for _level, mon in party]
    if not any(per_mon):
        return []
    shared = [kind for kind in per_mon[0] if all(kind in mon for mon in per_mon)]
    if not shared:
        counts = collections.Counter(kind for mon in per_mon for kind in mon)
        shared = [counts.most_common(1)[0][0]]
    return [kind.removesuffix("_TYPE").title() for kind in shared]


def _script_text(root_str, label):
    paths = sorted((sources._root(root_str) / "scripts").glob(f"{label}.asm")) + \
        sorted((sources._root(root_str) / "scripts").glob(f"{label}_[0-9].asm"))
    return "\n".join(path.read_text() for path in paths)


def build_places(root_str):
    """Return {map const: facts} for every map the game defines, skipping the ones with nothing
    to say (a plain route or a bare room keeps its name and needs no hint)."""
    dex = sources.parse_dex_numbers(root_str)
    marts, gifts = parse_marts(root_str), parse_gifts(root_str)
    out = {}
    for label, (const, tileset) in sorted(sources.parse_headers(root_str).items()):
        kind = place_kind(const, tileset)
        if kind == "outdoor":
            continue
        objects = sources.parse_object_events(root_str, label, include_battlers=True)
        facts = {"kind": kind}
        if kind == "gym" and (gym := gym_facts(root_str, label, objects)):
            facts["gym"] = gym
        if const in marts:
            facts["stock"] = [sources.item_display_name(i) for i in marts[const]]
        gift = gifts.get(const, {})
        if gift.get("mon"):
            facts["gift_mon"] = [{"dex": f"{dex[mon]:03d}", "level": level, "sold": sold}
                                 for mon, level, sold in gift["mon"]]
        if kind != "gym" and gift.get("item"):
            facts["gift_item"] = [{"name": tm_display_name(root_str, item), "qty": qty}
                                  for item, qty in gift["item"]]
        # a gym's leader is a trainer object too, but the copy counts them apart
        trainers = sum(o["kind"] == "trainer" for o in objects) - bool(facts.get("gym"))
        counts = {"trainers": trainers, "items": sum(o["kind"] == "item" for o in objects)}
        facts.update({k: v for k, v in counts.items() if v > 0})
        out[const] = facts
    return out
