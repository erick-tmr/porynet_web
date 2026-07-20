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
    assert len(objs) == 3
    oak = objs[0]
    assert oak["sprite_const"] == "SPRITE_OAK"
    assert oak["grid"] == (10, 4)
    assert oak["direction"] == "NONE"


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
