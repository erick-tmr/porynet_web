#!/usr/bin/env python3
"""The Pokédex facts the game itself prints, for the species a walkthrough step registers as seen.

A step where an NPC shows you a Pokémon you cannot catch yet has one thing to hand the reader: the
entry the game writes into the dex at that moment. All of it is in the disassembly, so it is read
rather than typed: `data/pokemon/dex_entries.asm` carries the species line ('SLEEPING'), its height
in feet and inches and its weight in tenths of a pound, `data/pokemon/dex_text.asm` the description,
and the base stats its types.

The description is stored as it is printed, in screen-width lines split across two pages, so it is
joined back into one paragraph here: the page break is a scroll in the game, not a sentence.
"""
import re
from functools import cache

import places
import sources

DEX_ENTRIES = "data/pokemon/dex_entries.asm"
DEX_TEXT = "data/pokemon/dex_text.asm"
BASE_STATS = "data/pokemon/base_stats"

# The game writes the species line without the word every dex screen prints after it.
SPECIES_SUFFIX = "POKéMON"

# `#` is the game's abbreviation for POKé, which is how POKéMON fits on an eighteen-character row.
# It is spelled out in a paragraph, split across a row break or not.
TEXT_TOKENS = {"#-MON": "POKéMON", "#MON": "POKéMON"}

ENDINGS = (".", "!", "?")

# The game calls Mr. Mime's type PSYCHIC_TYPE so the constant does not collide with the move of
# the same name. The dex screen prints the type, not the constant.
TYPE_SUFFIX = "_TYPE"

# Gen 1 is imperial only: heights are feet and inches, weights tenths of a pound. Most of the world
# reads metres and kilos, so both are printed, and the metric half is converted from the game's own
# figure rather than taken from a table. That leaves it a rounding step behind the number the
# official dex prints for a species whose real weight was set in kilos and rounded into pounds:
# Snorlax is 460.0 kg there and 459.9 kg here, because the cartridge stored 1014.0 lbs for what is
# really 1014.13.
INCH_M = 0.0254
POUND_KG = 0.45359237


def _text_blocks(root_str):
    """{label: description} for every _*DexEntry:: block in dex_text.asm.

    Each block is a run of `text`/`next`/`page` rows, closed either by a `dex` macro or by a `@`
    inside the last row itself; Koffing's is written the second way and would otherwise swallow
    every entry after it."""
    out = {}
    label = None
    rows = []
    for line in sources.read_data(root_str, DEX_TEXT).splitlines():
        start = re.match(r"^_(\w+)DexEntry::", line)
        if start:
            label, rows = start.group(1), []
            continue
        if label is None:
            continue
        row = re.match(r'^\s*(?:text|next|page)\s+"(.*)"\s*$', line)
        if row and "@" in row.group(1):
            rows.append(row.group(1).split("@", 1)[0])
            out[label], label = _paragraph(rows), None
        elif row:
            rows.append(row.group(1))
        elif re.match(r"^\s*dex\s*$", line):
            out[label], label = _paragraph(rows), None
    return out


def _paragraph(rows):
    """One screen's worth of rows joined back into a paragraph.

    A row broken mid-word ends on a hyphen, and the hyphen is kept rather than healed: the game
    cannot tell a break it inserted from one the word owns, and 'micro-scope' still reads, where
    dropping every hyphen would run 'harder-than-diamonds' together as 'harderthan-diamonds'."""
    text = ""
    for row in (row for row in rows if row):
        text += row if text.endswith("-") or not text else " " + row
    for token, word in TEXT_TOKENS.items():
        text = text.replace(token, word)
    text = re.sub(r"\s+", " ", text).strip()
    return text if text.endswith(ENDINGS) else text + "."


def _entries(root_str):
    """{label: (species line, feet, inches, tenths of a pound)} from dex_entries.asm."""
    out = {}
    pattern = re.compile(
        r'^(\w+)DexEntry:\s*\n\s*db\s+"([^"@]*)@"\s*\n\s*db\s+(\d+)\s*,\s*(\d+)\s*\n\s*dw\s+(\d+)',
        re.M)
    for label, species, feet, inches, weight in pattern.findall(
            sources.read_data(root_str, DEX_ENTRIES)):
        out[label] = (species, int(feet), int(inches), int(weight))
    return out


def _height(feet, inches):
    metres = (feet * 12 + inches) * INCH_M
    return f"{feet}'{inches:02d}\" ({metres:.1f} m)"


def _weight(tenths):
    pounds = tenths / 10
    return f"{pounds:.1f} lbs ({pounds * POUND_KG:.1f} kg)"


def _type_name(const):
    return const[:-len(TYPE_SUFFIX)] if const.endswith(TYPE_SUFFIX) else const


@cache
def base_stats(root_str):
    """{species const: {hp, attack, defense, speed, special, base_exp}} from the base stats files.

    The stat line is one `db` of five numbers under a comment naming them, and the experience a
    knockout pays is its own `db` further down. Both are what a grinding spot is judged on: how
    fast the thing moves, how little it takes to drop, and what it pays for the trouble."""
    out = {}
    for path in sorted((sources._root(root_str) / BASE_STATS).glob("*.asm")):
        text = path.read_text()
        line = re.search(r"^\s*db\s+(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\s*$", text, re.M)
        exp = re.search(r"^\s*db\s+(\d+)\s*;\s*base exp", text, re.M)
        if line and exp:
            hp, attack, defense, speed, special = (int(n) for n in line.groups())
            out[path.stem.upper()] = {"hp": hp, "attack": attack, "defense": defense,
                                      "speed": speed, "special": special,
                                      "base_exp": int(exp.group(1))}
    return out


def _label_for(const):
    """'NIDORAN_M' -> 'NidoranM', the CamelCase the dex labels use.

    The base stats file for the same species drops the underscore instead ('nidoranm.asm'), which
    is why the type lookup strips it rather than reusing this."""
    return "".join(part.capitalize() for part in const.split("_"))


def build_dex(root_str):
    """{dex number: entry} for every species the game gives a real entry.

    Keyed by dex number rather than by species constant, because that is what a step names: the
    walkthrough asks for 143 and gets back everything the screen would show for it."""
    numbers = sources.parse_dex_numbers(root_str)
    types = places.parse_pokemon_types(root_str)
    stats = base_stats(root_str)
    blocks = _text_blocks(root_str)
    entries = _entries(root_str)
    out = {}
    for const, number in numbers.items():
        label = _label_for(const)
        if label not in entries or label not in blocks:
            continue
        species, feet, inches, weight = entries[label]
        out[f"{number:03d}"] = {
            "name": sources.item_display_name(const),
            "species": f"{species} {SPECIES_SUFFIX}",
            "types": [_type_name(name)
                      for name in types.get(const.replace("_", ""), types.get(const, ()))],
            "height": _height(feet, inches),
            "weight": _weight(weight),
            "text": blocks[label],
            **stats.get(const.replace("_", ""), stats.get(const, {})),
        }
    return out
