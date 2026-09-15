"""The readers that have to cope with two spellings of the same game data.

Yellow Legacy forked pokeyellow before a run of upstream renames, so a handful of files it
ships are the older shape: the hide/show table is one flat list instead of two paired ones,
the wild slot odds are raw cut points instead of a macro, the GBC palette table has a
different label, and the Old Rod has a table of its own. Each reader takes both, and these
build the older shape from scratch so the tests say what the shape is rather than pointing at
a checkout that may not be there."""
import pytest

import encounters
import sources


def write(root, rel, text):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


# --- hide/show ---------------------------------------------------------------

HIDE_SHOW = """\
MapHSPointers:
	dw PalletTownHS
PalletTownHS:
	db PALLET_TOWN, PALLETTOWN_OAK, HIDE
ViridianCityHS:
	db VIRIDIAN_CITY, VIRIDIANCITY_OLD_MAN_SLEEPY, SHOW
	db VIRIDIAN_CITY, VIRIDIANCITY_OLD_MAN,        HIDE
	db $FF, $01, SHOW ; end
"""

HS_CONSTS = """\
	const_def
	const HS_PALLET_TOWN_OAK               ; 00
	const HS_LYING_OLD_MAN                 ; 01
	const HS_OLD_MAN_1                     ; 02
"""


@pytest.fixture
def flat(tmp_path):
    write(tmp_path, "data/maps/hide_show_data.asm", HIDE_SHOW)
    write(tmp_path, "constants/hide_show_constants.asm", HS_CONSTS)
    return str(tmp_path)


def test_a_flat_row_names_its_own_map_so_nothing_is_paired_by_position(flat):
    assert sources.parse_hidden_objects(flat) == {
        "PALLET_TOWN": {"PALLETTOWN_OAK"},
        "VIRIDIAN_CITY": {"VIRIDIANCITY_OLD_MAN"},
    }


def test_the_terminator_row_is_not_an_object(flat):
    """The table ends `db $FF, $01, SHOW`, which is a sentinel rather than a map and an object."""
    assert "$FF" not in sources.parse_hidden_objects(flat)


def test_a_handle_resolves_through_its_index_in_the_flat_table(flat):
    assert sources.resolve_toggle(flat, "PALLET_TOWN", "HS_PALLET_TOWN_OAK") == "PALLETTOWN_OAK"
    assert sources.resolve_toggle(flat, "VIRIDIAN_CITY", "HS_OLD_MAN_1") == "VIRIDIANCITY_OLD_MAN"


def test_a_handle_belonging_to_another_map_resolves_to_nothing(flat):
    assert sources.resolve_toggle(flat, "PALLET_TOWN", "HS_OLD_MAN_1") is None


def test_an_unknown_handle_resolves_to_nothing(flat):
    assert sources.resolve_toggle(flat, "PALLET_TOWN", "HS_NOT_A_THING") is None


def test_a_handle_past_the_end_of_the_table_resolves_to_nothing(tmp_path):
    write(tmp_path, "data/maps/hide_show_data.asm", "PalletTownHS:\n\tdb PALLET_TOWN, OAK, HIDE\n")
    write(tmp_path, "constants/hide_show_constants.asm",
          "\tconst_def\n\tconst HS_ONE\n\tconst HS_TWO\n")
    assert sources.resolve_toggle(str(tmp_path), "PALLET_TOWN", "HS_TWO") is None


# --- wild slot odds ----------------------------------------------------------

CUT_POINTS = """\
WildMonEncounterSlotChances:
	db  50, $00 ; 19.9%
	db 101, $02
	db 140, $04
	db 165, $06
	db 190, $08
	db 215, $0A
	db 228, $0C
	db 241, $0E
	db 252, $10
	db 255, $12
"""


def test_raw_cut_points_read_as_the_same_odds_the_macro_spells_out(tmp_path):
    """The ladder is cumulative: a slot's share is the gap to the one below it, and the first
    covers everything at or under its byte. Read that way the older table is the same table."""
    write(tmp_path, "data/wild/probabilities.asm", CUT_POINTS)
    assert encounters.slot_weights(str(tmp_path)) == [51, 51, 39, 25, 25, 25, 13, 13, 11, 3]


def test_odds_that_do_not_account_for_every_encounter_are_refused(tmp_path):
    write(tmp_path, "data/wild/probabilities.asm", "\tdb  50, $00\n\tdb 101, $02\n")
    with pytest.raises(ValueError, match="not 256"):
        encounters.slot_weights(str(tmp_path))


# --- the Old Rod -------------------------------------------------------------

def test_the_old_rod_reads_its_table_when_the_game_ships_one(tmp_path):
    write(tmp_path, "data/wild/old_rod.asm",
          "OldRodMons:\n\tdb 5, GOLDEEN\n\tdb 5, POLIWAG\n")
    assert encounters.old_rod_mons(str(tmp_path)) == [("GOLDEEN", 5), ("POLIWAG", 5)]


def test_the_old_rod_falls_back_to_the_fixed_catch_with_no_table(tmp_path):
    assert encounters.old_rod_mons(str(tmp_path)) == [encounters.OLD_ROD_MON]


def test_two_old_rod_species_split_the_catch_evenly(tmp_path):
    write(tmp_path, "data/wild/old_rod.asm", "\tdb 5, GOLDEEN\n\tdb 5, POLIWAG\n")
    table = encounters.rod_table(str(tmp_path), "ROUTE_4", "old_rod")
    assert {s: e["weight"] for s, e in table.items()} == {"GOLDEEN": 128, "POLIWAG": 128}


# --- the Super Rod -----------------------------------------------------------

def test_code_after_the_super_rod_table_is_not_read_as_data(tmp_path):
    """Some games hang a routine off the bottom of the file. The table ends at its own
    terminator, so the parse has to stop there rather than at the end of the text."""
    write(tmp_path, "data/wild/super_rod.asm", """\
SuperRodFishingSlots:
	db ROUTE_4, POLIWAG, 15, GOLDEEN, 15, KRABBY, 15, SEAKING, 15
	db -1 ; end

CheckMapForFishingMon:
	db ROUTE_9, DRATINI, 15, DRATINI, 15, DRATINI, 15, DRATINI, 15
""")
    assert list(encounters.super_rod_slots(str(tmp_path))) == ["ROUTE_4"]


# --- palettes ----------------------------------------------------------------

def palette_file(label):
    rows = "\n".join(["\tRGB 31,31,31, 21,21,21, 10,10,10, 0,0,0"] * 2)
    return f"{label}:\n{rows}\n\tassert_table_length 2\n"


@pytest.mark.parametrize("label", ["CGBBasePalettes", "GBCBasePalettes"])
def test_the_gbc_palette_table_is_found_under_either_label(tmp_path, label):
    write(tmp_path, "data/sgb/sgb_palettes.asm", palette_file(label))
    assert len(sources.parse_cgb_palettes(str(tmp_path))) == 2


def test_no_palette_table_at_all_is_a_parse_failure_not_a_colorless_game(tmp_path):
    """An empty list used to travel several frames before failing, as an index error inside the
    compositor. The file is the wrong shape, so say so here."""
    write(tmp_path, "data/sgb/sgb_palettes.asm", palette_file("SomethingElse"))
    with pytest.raises(ValueError, match="no GBC base palette table"):
        sources.parse_cgb_palettes(str(tmp_path))


def test_a_row_naming_its_object_by_number_still_takes_up_its_index(tmp_path):
    """One row in the older table names an object on an unused map as a raw `$02`. It is still
    an indexed entry, so skipping it shifts every handle after it onto the wrong object, which
    is how a boulder stopped being dropped down the right hole four floors later."""
    write(tmp_path, "data/maps/hide_show_data.asm", """\
FirstHS:
	db PALLET_TOWN, PALLETTOWN_OAK, HIDE
UnusedMapF4HS:
	db UNUSED_MAP_F4, $02, SHOW ; unused
LastHS:
	db VIRIDIAN_CITY, VIRIDIANCITY_OLD_MAN, HIDE
	db $FF, $01, SHOW ; end
""")
    write(tmp_path, "constants/hide_show_constants.asm",
          "\tconst_def\n\tconst HS_OAK\n\tconst HS_UNUSED\n\tconst HS_OLD_MAN\n")
    root = str(tmp_path)
    assert len(sources._hide_show_rows(root)) == 3
    assert sources.resolve_toggle(root, "VIRIDIAN_CITY", "HS_OLD_MAN") == "VIRIDIANCITY_OLD_MAN"


# --- hidden objects ----------------------------------------------------------

HIDDEN_OBJECTS = """\
HiddenObjectMaps:
	dbw VIRIDIAN_FOREST, ViridianForestHiddenObjects
	dbw CINNABAR_GYM,    CinnabarGymHiddenObjects

ViridianForestHiddenObjects:
	hidden_object  1, 18, POTION, HiddenItems
	hidden_object 16, 42, ANTIDOTE, HiddenItems
	db -1 ; end

CinnabarGymHiddenObjects:
	hidden_object 15,  7, (FALSE << 4) | 1, PrintCinnabarQuiz
	hidden_object 10,  1, (TRUE  << 4) | 2, PrintCinnabarQuiz
	db -1 ; end
"""


@pytest.fixture
def objects(tmp_path):
    write(tmp_path, "data/events/hidden_objects.asm", HIDDEN_OBJECTS)
    return str(tmp_path)


def test_a_hidden_item_is_named_by_its_item_not_by_the_routine_that_hands_it_over(objects):
    """The older macro takes the item before the routine. Read in the newer order every hidden
    item in the game comes out called HiddenItems."""
    assert sources.parse_hidden_events(objects) == [
        ("VIRIDIAN_FOREST", 1, 18, "POTION"),
        ("VIRIDIAN_FOREST", 16, 42, "ANTIDOTE"),
    ]


def test_a_map_is_reached_through_the_index_rather_than_a_heading(objects):
    block = sources.hidden_block(objects, "VIRIDIAN_FOREST")
    assert "POTION" in block and "ANTIDOTE" in block
    assert "PrintCinnabarQuiz" not in block


def test_a_map_with_no_hidden_objects_has_no_block(objects):
    assert sources.hidden_block(objects, "PALLET_TOWN") is None
