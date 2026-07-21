import pytest

import sources


def test_map_constants(root):
    dims, num_city, first_indoor = sources.parse_map_constants(root)
    assert dims["PALLET_TOWN"] == (0, 10, 9)      # (index, width, height in blocks)
    assert num_city and first_indoor and num_city < first_indoor


def test_headers(root):
    assert sources.parse_headers(root)["PalletTown"] == ("PALLET_TOWN", "OVERWORLD")


def test_sprite_table(root):
    table = sources.parse_sprite_table(root)
    assert table["SPRITE_OAK"] == "oak"
    assert table["SPRITE_RED"] == "red"
    assert table["SPRITE_FISHER"] == "fisher"


def test_object_events(root):
    objs = sources.parse_object_events(root, "PalletTown")
    assert len(objs) == 2
    girl = objs[0]
    assert girl["sprite_const"] == "SPRITE_GIRL"
    assert girl["const"] == "PALLETTOWN_GIRL"


def test_object_events_leave_out_the_cutscene_only(root):
    """Oak stands in Pallet Town only long enough to stop you walking into the grass. The game
    ships him switched off, so a map drawn from the object list alone would strand him there."""
    assert "PALLETTOWN_OAK" in sources.parse_hidden_objects(root)["PALLET_TOWN"]

    drawn = sources.parse_object_events(root, "PalletTown", include_battlers=True)
    assert "SPRITE_OAK" not in {o["sprite_const"] for o in drawn}
    assert "PALLETTOWN_OAK" in {o["const"] for o in sources._object_events(root, "PalletTown")}


def test_the_rival_does_not_wait_on_route_22_forever(root):
    """Both Route 22 rivals are switched off until the fight is due."""
    assert not [o for o in sources.parse_object_events(root, "Route22", include_battlers=True)
                if o["kind"] == "trainer"]


def test_object_events_missing_map(root):
    assert sources.parse_object_events(root, "NoSuchMap") == ()


def test_object_event_kinds(root):
    objs = sources.parse_object_events(root, "ViridianForest", include_battlers=True)
    by_grid = {o["grid"]: o for o in objs}

    person = by_grid[(16, 43)]
    assert person["kind"] == "person"
    assert person["text_const"] == "TEXT_VIRIDIANFOREST_YOUNGSTER1"

    trainer = by_grid[(30, 33)]
    assert trainer["kind"] == "trainer"
    assert (trainer["opp_class"], trainer["party"]) == ("BUG_CATCHER", 1)

    item = by_grid[(25, 11)]
    assert item["kind"] == "item"
    assert item["item_const"] == "POTION"


def test_object_events_excludes_battlers_by_default(root):
    objs = sources.parse_object_events(root, "ViridianForest")
    assert [o["grid"] for o in objs] == [(16, 43), (27, 40)]


def test_object_events_scripted_ball_is_a_person(root):
    """The Oak's Lab Eevee takes the 6-arg form, so it draws as a sprite but offers no item."""
    ball = next(o for o in sources.parse_object_events(root, "OaksLab", include_battlers=True)
                if o["sprite_const"] == "SPRITE_POKE_BALL")
    assert ball["kind"] == "person"
    assert ball["item_const"] is None


def test_warp_events(root):
    warps = sources.parse_warp_events(root, "ViridianForest")
    assert len(warps) == 6
    assert warps[0] == (1, 0, "VIRIDIAN_FOREST_NORTH_GATE", 3)
    assert {w[2] for w in warps} == {"VIRIDIAN_FOREST_NORTH_GATE", "VIRIDIAN_FOREST_SOUTH_GATE"}


def test_warp_events_missing_map(root):
    assert sources.parse_warp_events(root, "NoSuchMap") == ()


def test_warp_events_skips_debug_only_warps(root):
    """Red's bedroom keeps four IF DEF(_DEBUG) warps that the retail ROM never assembles."""
    warps = sources.parse_warp_events(root, "RedsHouse2F")
    assert warps == ((7, 1, "REDS_HOUSE_1F", 3),)


def test_border_block(root):
    assert sources.parse_border_block(root, "ViridianForest") == 0x3
    assert sources.parse_border_block(root, "NoSuchMap") is None


def test_item_display_name():
    assert sources.item_display_name("POKE_BALL") == "Poké Ball"
    assert sources.item_display_name("ELIXER") == "Elixir"
    assert sources.item_display_name("TM_BLIZZARD") == "TM Blizzard"
    assert sources.item_display_name("HM_SURF") == "HM Surf"
    assert sources.item_display_name("MOON_STONE") == "Moon Stone"


def test_trainer_parties_plain_form(root):
    """`db <level>, <SPECIES>, ..., 0` gives the whole team one level."""
    assert sources.parse_trainer_parties(root)["BUG_CATCHER"][3] == (
        (10, "CATERPIE"), (10, "WEEDLE"), (10, "CATERPIE"))


def test_trainer_parties_per_mon_levels(root):
    """`db $FF, <level>, <SPECIES>, ...` gives each mon its own level."""
    assert sources.parse_trainer_parties(root)["RIVAL1"][2] == (
        (18, "SPEAROW"), (15, "SANDSHREW"), (15, "RATTATA"), (17, "EEVEE"))


def test_every_trainer_class_has_a_party_block(root):
    """UNUSED_JUGGLER and CHIEF are the two classes the game never fields; their blocks read
    `; none`. Every other class has at least one party."""
    parties = sources.parse_trainer_parties(root)

    assert set(parties) == set(sources._trainer_const_order(root)[1:])
    assert {k for k, v in parties.items() if not v} == {"UNUSED_JUGGLER", "CHIEF"}


def test_trainer_data_labels_are_not_camel_cased_consts(root):
    """Reading the pointer table is what gets these three right."""
    labels = sources._trainer_data_labels(root)

    assert labels["BLACKBELT"] == "Blackbelt"
    assert labels["JR_TRAINER_M"] == "JrTrainerM"
    assert labels["PSYCHIC_TR"] == "Psychic"


def test_trainer_money(root):
    money = sources.parse_trainer_money(root)

    assert money["BUG_CATCHER"] == 1000
    assert money["MISTY"] == 9900
    assert money["JUGGLER"] == money["UNUSED_JUGGLER"] == 3500


def test_trainer_reward_matches_the_hand_authored_numbers(root):
    """Base money over 100, times the last mon's level. These five were verified by hand."""
    for const, party_no, want in [("BUG_CATCHER", 4, 100), ("LASS", 19, 90),
                                  ("YOUNGSTER", 1, 165), ("BROCK", 1, 1188), ("MISTY", 1, 2079)]:
        party = sources.trainer_party(root, const, party_no)
        assert sources.trainer_reward(root, const, party) == want, f"{const}:{party_no}"


def test_trainer_party_out_of_range(root):
    with pytest.raises(KeyError):
        sources.trainer_party(root, "BUG_CATCHER", 99)


def test_dex_numbers(root):
    dex = sources.parse_dex_numbers(root)

    assert len(dex) == 151
    assert dex["BULBASAUR"] == 1
    assert dex["NIDORAN_M"] == 32
    assert dex["MEW"] == 151


def test_collision_tiles_reads_a_stacked_label(root):
    """Dojo and Gym share one `coll_tiles` line under stacked labels. The first label must resolve
    to that shared set; before, it read as nothing walkable and the whole Fighting Dojo looked
    solid, so the where-scene hero had no floor to stand on."""
    dojo = sources.parse_collision_tiles(root, "DOJO")
    mart = sources.parse_collision_tiles(root, "MART")

    assert dojo and dojo == sources.parse_collision_tiles(root, "GYM")
    assert mart and mart == sources.parse_collision_tiles(root, "POKECENTER")


def test_place_display_name():
    assert sources.place_display_name("VIRIDIAN_FOREST_NORTH_GATE") == "Viridian Forest North Gate"
    assert sources.place_display_name("SS_ANNE_1F") == "S.S. Anne 1F"
    assert sources.place_display_name("MT_MOON_B1F") == "Mt. Moon B1F"
    assert sources.place_display_name("MT_MOON") == "Mt. Moon"
    assert sources.place_display_name("POKEMON_TOWER_2F") == "Pokemon Tower 2F"
    assert sources.place_display_name("LAST_MAP") == "Back outside"


def test_charmap(root):
    cm = sources.parse_charmap(root)
    assert cm["A"] == 0x80
    assert cm["z"] == 0xB9
    assert cm[" "] == 0x7F
    assert cm["!"] == 0xE7
    assert cm["é"] == 0xBA
    assert cm["<PLAYER>"] == 0x52


def test_trainer_classes(root):
    classes = sources.parse_trainer_classes(root)
    assert classes["BROCK"][1] == "BROCK"
    assert classes["MISTY"][1] == "MISTY"
    assert classes["RIVAL1"][1] == "RIVAL1"
    assert classes["LANCE"][1] == "LANCE"


def test_trainer_pic_file(root):
    # filenames the const does not lowercase into
    assert sources.parse_trainer_pic_file(root, "RIVAL1") == "rival1"
    assert sources.parse_trainer_pic_file(root, "JR_TRAINER_M") == "jr.trainerm"
    assert sources.parse_trainer_pic_file(root, "PROF_OAK") == "prof.oak"
    assert sources.parse_trainer_pic_file(root, "LT_SURGE") == "lt.surge"


def test_markers_by_map(root):
    vf = sources.markers_by_map(root)["VIRIDIAN_FOREST"]
    antidote = next(m for m in vf if m["item_const"] == "ANTIDOTE")
    assert antidote["label"] == "Antidote"
    assert antidote["grid"] == [16, 42]
