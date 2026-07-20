#!/usr/bin/env python3
"""Read structured data out of the pret/pokeyellow disassembly.

Every parser takes the pokeyellow root as a string and is @lru_cache'd on it, so the
whole disassembly is parsed at most once per run. Nothing here touches PIL geometry; the
compositor and generators build images on top of what these return.

Covers: map dimensions/headers, tilesets/blocksets/palettes (the map render inputs),
overworld sprite ids, map object events (NPCs), the text charmap, trainer classes and
their battle pics, and the game's hidden-item / Game Corner coin coordinates.
"""
import re
import pathlib
from functools import lru_cache

from PIL import Image

TILE_PX = 8
BLOCK_TILES = 4                    # tiles per block side
BLOCK_PX = BLOCK_TILES * TILE_PX   # 32
UNIT_PX = 16                       # one overworld movement-grid cell

# PAL_* ids (constants/palette_constants.asm)
PAL_ROUTE = 0
PAL_GRAYMON = 0x19
PAL_CAVE = 0x23
PAL_YELLOWMON = 0x18   # the Pikachu-yellow palette; our default battle tint


@lru_cache(maxsize=None)
def _root(root_str):
    return pathlib.Path(root_str)


def _read(root_str, rel):
    return (_root(root_str) / rel).read_text()


def _rgb5_to_8(v):
    return (v << 3) | (v >> 2)


def _snake_to_camel(name):
    return "".join(part.capitalize() for part in name.split("_"))


# --- maps -------------------------------------------------------------------

@lru_cache(maxsize=None)
def parse_map_constants(root_str):
    """Return ({const: (index, width, height)}, num_city_maps, first_indoor_map)."""
    dims, idx = {}, 0
    num_city = first_indoor = None
    for line in _read(root_str, "constants/map_constants.asm").splitlines():
        m = re.match(r"\s*map_const\s+(\w+)\s*,\s*(\d+)\s*,\s*(\d+)", line)
        if m:
            dims[m.group(1)] = (idx, int(m.group(2)), int(m.group(3)))
            idx += 1
            continue
        if re.match(r"\s*DEF\s+NUM_CITY_MAPS\s+EQU\s+const_value", line):
            num_city = idx
        elif re.match(r"\s*DEF\s+FIRST_INDOOR_MAP\s+EQU\s+const_value", line):
            first_indoor = idx
    return dims, num_city, first_indoor


@lru_cache(maxsize=None)
def parse_headers(root_str):
    """Return {label: (const, tileset)} for every map header."""
    out = {}
    for path in sorted((_root(root_str) / "data/maps/headers").glob("*.asm")):
        for line in path.read_text().splitlines():
            m = re.match(r"\s*map_header\s+(\w+)\s*,\s*(\w+)\s*,\s*(\w+)", line)
            if m:
                out[m.group(1)] = (m.group(2), m.group(3))
    return out


@lru_cache(maxsize=None)
def parse_tileset_files(root_str):
    """Map tileset name (CamelCase) -> its shared gfx/blockset basename via gfx/tilesets.asm.
    Some tilesets (RedsHouse1/RedsHouse2, ...) share one file, so the const does not lowercase
    straight to a filename."""
    mapping, pending = {}, []
    for line in _read(root_str, "gfx/tilesets.asm").splitlines():
        m = re.match(r"\s*(\w+)_GFX::", line)
        if m:
            pending.append(m.group(1))
        inc = re.search(r'INCBIN\s+"gfx/tilesets/([\w-]+)\.2bpp"', line)
        if inc and pending:
            for name in pending:
                mapping[name] = inc.group(1)
            pending = []
    return mapping


def tileset_basename(root_str, tileset_const):
    return parse_tileset_files(root_str).get(_snake_to_camel(tileset_const), tileset_const.lower())


def _parse_rgb_palette_table(root_str, label):
    """Return [ [ (r,g,b)*4 ], ... ] from an `RGB c,c,c, ...` table in sgb_palettes.asm,
    indexed by PAL_* id. Reads from `label:` until the next label / assert_table_length."""
    pals, collecting = [], False
    for line in _read(root_str, "data/sgb/sgb_palettes.asm").splitlines():
        if re.match(rf"^{label}:", line):
            collecting = True
            continue
        if collecting:
            if re.match(r"^\w+:", line) or re.match(r"\s*assert_table_length", line):
                break
            m = re.match(r"\s*RGB\s+(.+?)(?:;.*)?$", line)
            if not m:
                continue
            nums = [int(n) for n in re.findall(r"\d+", m.group(1))]
            if len(nums) >= 12:
                pals.append([tuple(_rgb5_to_8(nums[i + c]) for c in range(3))
                             for i in range(0, 12, 3)])
    return pals


@lru_cache(maxsize=None)
def parse_super_palettes(root_str):
    """The Super Game Boy palettes (paler), indexed by PAL_* id."""
    return _parse_rgb_palette_table(root_str, "SuperPalettes")


@lru_cache(maxsize=None)
def parse_cgb_palettes(root_str):
    """The Game Boy Color base palettes (more saturated, the GBC look), indexed by PAL_* id."""
    return _parse_rgb_palette_table(root_str, "CGBBasePalettes")


@lru_cache(maxsize=None)
def load_tiles(root_str, tileset_file):
    """Return a list of 8x8 'L'-mode tiles from gfx/tilesets/<file>.png (row-major)."""
    png = Image.open(_root(root_str) / f"gfx/tilesets/{tileset_file}.png").convert("L")
    cols, rows = png.width // TILE_PX, png.height // TILE_PX
    return [png.crop((tx * TILE_PX, ty * TILE_PX, tx * TILE_PX + TILE_PX, ty * TILE_PX + TILE_PX))
            for ty in range(rows) for tx in range(cols)]


@lru_cache(maxsize=None)
def load_blockset(root_str, tileset_file):
    """Return a list of blocks; each block is 16 tile indices (4x4 row-major)."""
    data = (_root(root_str) / f"gfx/blocksets/{tileset_file}.bst").read_bytes()
    return [list(data[i:i + 16]) for i in range(0, len(data), 16)]


def load_blueprint(root_str, label):
    """Return the raw block-index bytes for maps/<label>.blk."""
    return (_root(root_str) / f"maps/{label}.blk").read_bytes()


@lru_cache(maxsize=None)
def load_sprite_sheet(root_str, name):
    """The 'L'-mode overworld sprite sheet gfx/sprites/<name>.png.

    Cached because a full build composites hundreds of sprites drawn from a few dozen sheets.
    Callers must only crop/transpose it, which return new images and leave the cache intact."""
    return Image.open(_root(root_str) / f"gfx/sprites/{name}.png").convert("L")


@lru_cache(maxsize=None)
def load_emote_sheet(root_str, name):
    """The 'L'-mode emotion-bubble sheet gfx/emotes/<name>.png. Cached like load_sprite_sheet."""
    return Image.open(_root(root_str) / f"gfx/emotes/{name}.png").convert("L")


def resolve_palette_id(root_str, const, tileset, parent_const):
    """Mirror SetPal_Overworld: pick the map's super-palette id."""
    if tileset == "CEMETERY":
        return PAL_GRAYMON
    if tileset == "CAVERN":
        return PAL_CAVE
    dims, num_city, first_indoor = parse_map_constants(root_str)
    idx = dims[const][0]
    if idx >= first_indoor and parent_const and parent_const in dims:
        idx = dims[parent_const][0]           # interiors inherit their town/route
    if idx < num_city:
        return idx + 1                        # a town's palette id is its map id + 1
    return PAL_ROUTE


# --- overworld sprites + NPCs ----------------------------------------------

@lru_cache(maxsize=None)
def _sprite_label_files(root_str):
    """Map an overworld sprite label (e.g. RedSprite) -> gfx/sprites basename (red)."""
    out = {}
    for line in _read(root_str, "gfx/sprites.asm").splitlines():
        m = re.match(r'\s*(\w+)::\s*INCBIN\s+"gfx/sprites/(\w+)\.2bpp"', line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


@lru_cache(maxsize=None)
def parse_sprite_table(root_str):
    """Map a sprite id constant (SPRITE_RED) -> its gfx/sprites basename (red).

    SpriteSheetPointerTable rows are `overworld_sprite <Label>, N ; SPRITE_<CONST>`; the
    label resolves to the .2bpp/.png basename via gfx/sprites.asm (handles snake_case names
    and aliases like SPRITE_UNUSED_RED_1 -> RedSprite -> red)."""
    labels = _sprite_label_files(root_str)
    out = {}
    for line in _read(root_str, "data/sprites/sprites.asm").splitlines():
        m = re.match(r"\s*overworld_sprite\s+(\w+)\s*,\s*\d+.*;\s*(SPRITE_\w+)", line)
        if m and m.group(1) in labels:
            out[m.group(2)] = labels[m.group(1)]
    return out


@lru_cache(maxsize=None)
def parse_border_block(root_str, map_label):
    """The map's border block id (`db $X ; border block` in its object file); None if absent.

    Gen 1 fills every on-screen cell beyond the map edge with this block (grass/water outdoors,
    a solid black block inside buildings)."""
    path = _root(root_str) / f"data/maps/objects/{map_label}.asm"
    if not path.exists():
        return None
    for line in path.read_text().splitlines():
        m = re.match(r"\s*db\s+\$([0-9A-Fa-f]+)\s*;\s*border block", line)
        if m:
            return int(m.group(1), 16)
    return None


def parse_object_events(root_str, map_label, include_battlers=False):
    """Return the map's person objects as [{grid:(x,y), sprite_const, movement, direction}].

    Reads data/maps/objects/<map_label>.asm. Plain 6-arg object_events (people) are always
    returned; trainer/item objects carry extra trailing args and are included only when
    `include_battlers` is set (e.g. to show a gym's leader and trainers on its map). Source
    coords are the raw 16px movement grid (the +4 border the macro adds is a detail we drop)."""
    path = _root(root_str) / f"data/maps/objects/{map_label}.asm"
    if not path.exists():
        return ()
    out = []
    for line in path.read_text().splitlines():
        body = line.split(";", 1)[0]
        m = re.match(
            r"\s*object_event\s+(\d+)\s*,\s*(\d+)\s*,\s*(SPRITE_\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*(,.*)?$",
            body)
        if m and (include_battlers or not m.group(7)):
            out.append({"grid": (int(m.group(1)), int(m.group(2))), "sprite_const": m.group(3),
                        "movement": m.group(4), "direction": m.group(5)})
    return tuple(out)


# --- text / charmap ---------------------------------------------------------

@lru_cache(maxsize=None)
def parse_charmap(root_str):
    """Return {token: byte} from constants/charmap.asm (e.g. 'A'->0x80, ' '->0x7f, '<PLAYER>'->0x52)."""
    out = {}
    for line in _read(root_str, "constants/charmap.asm").splitlines():
        m = re.match(r'\s*charmap\s+"(.*)",\s*\$([0-9A-Fa-f]+)', line)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out


# --- trainers / battle ------------------------------------------------------

@lru_cache(maxsize=None)
def _trainer_const_order(root_str):
    """Ordered trainer class consts from constants/trainer_constants.asm (NOBODY first)."""
    return tuple(m.group(1) for line in _read(root_str, "constants/trainer_constants.asm").splitlines()
                 if (m := re.match(r"\s*trainer_const\s+(\w+)", line)))


@lru_cache(maxsize=None)
def parse_trainer_classes(root_str):
    """Map trainer class const -> (index, display name).

    names.asm lists names from YOUNGSTER onward, aligned to the const order minus NOBODY."""
    consts = _trainer_const_order(root_str)
    names = re.findall(r'^\s*li\s+"(.*)"', _read(root_str, "data/trainers/names.asm"), re.M)
    out = {}
    for i, name in enumerate(names):
        const = consts[i + 1] if i + 1 < len(consts) else None   # +1 skips NOBODY
        if const:
            out[const] = (i, name)
    return out


@lru_cache(maxsize=None)
def _trainer_pic_labels(root_str):
    """Ordered pic labels from pic_pointers_money.asm, aligned to consts minus NOBODY."""
    return tuple(m.group(1) for line in _read(root_str, "data/trainers/pic_pointers_money.asm").splitlines()
                 if (m := re.match(r"\s*pic_money\s+(\w+)", line)))


@lru_cache(maxsize=None)
def _trainer_pic_files(root_str):
    """Map a trainer pic label (Rival1Pic) -> gfx/trainers basename (rival1)."""
    out = {}
    for line in _read(root_str, "gfx/pics.asm").splitlines():
        m = re.match(r'\s*(\w+)::\s*INCBIN\s+"gfx/trainers/([\w.]+)\.pic"', line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def parse_trainer_pic_file(root_str, trainer_const):
    """Return the gfx/trainers basename for a trainer class const (e.g. RIVAL1 -> rival1)."""
    classes = parse_trainer_classes(root_str)
    if trainer_const not in classes:
        raise KeyError(f"unknown trainer class {trainer_const}")
    label = _trainer_pic_labels(root_str)[classes[trainer_const][0]]
    files = _trainer_pic_files(root_str)
    if label not in files:
        raise KeyError(f"no trainer pic file for {trainer_const} ({label})")
    return files[label]


# --- hidden items / coins ---------------------------------------------------

# item constants pokeyellow spells differently from the display name
_ITEM_FIXUPS = {"ELIXER": "Elixir", "MAX_ELIXER": "Max Elixir", "HP_UP": "HP Up",
                "PP_UP": "PP Up", "TM": "TM"}


def item_display_name(const):
    if const in _ITEM_FIXUPS:
        return _ITEM_FIXUPS[const]
    if const.startswith("TM_") or const.startswith("HM_"):
        return const.replace("_", " ")
    return const.replace("_", " ").title()


def _cell_px(x, y):
    return [x * UNIT_PX + UNIT_PX // 2, y * UNIT_PX + UNIT_PX // 2]


@lru_cache(maxsize=None)
def parse_hidden_events(root_str):
    """Return [(map_const, x, y, item_const)] for FUNC == HiddenItems only."""
    out, cur = [], None
    for line in _read(root_str, "data/events/hidden_events.asm").splitlines():
        m = re.match(r"\s*hidden_events_for\s+(\w+)", line)
        if m:
            cur = m.group(1)
            continue
        m = re.match(r"\s*hidden_event\s+(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*(\w+)", line)
        if m and cur and m.group(3) == "HiddenItems":
            out.append((cur, int(m.group(1)), int(m.group(2)), m.group(4)))
    return out


@lru_cache(maxsize=None)
def parse_coins(root_str):
    """Return [(map_const, x, y)] for hidden coins."""
    out = []
    for line in _read(root_str, "data/events/hidden_coins.asm").splitlines():
        m = re.match(r"\s*hidden_coin\s+(\w+)\s*,\s*(\d+)\s*,\s*(\d+)", line)
        if m:
            out.append((m.group(1), int(m.group(2)), int(m.group(3))))
    return out


@lru_cache(maxsize=None)
def markers_by_map(root_str):
    """Return {map_const: [ {kind, item_const, label, grid:[x,y], px:[x,y]} ]}."""
    out = {}
    for const, x, y, item in parse_hidden_events(root_str):
        out.setdefault(const, []).append(
            {"kind": "item", "item_const": item, "label": item_display_name(item),
             "grid": [x, y], "px": _cell_px(x, y)})
    for const, x, y in parse_coins(root_str):
        out.setdefault(const, []).append(
            {"kind": "coin", "item_const": "COIN", "label": "Coins",
             "grid": [x, y], "px": _cell_px(x, y)})
    return out
