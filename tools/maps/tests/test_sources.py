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
