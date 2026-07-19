import build


def test_image_name_floors():
    assert build.image_name("mt-moon", "") == "mt-moon"
    assert build.image_name("mt-moon", "B1F") == "mt-moon-b1f"
    assert build.image_name("safari-zone", "Center") == "safari-zone-center"


def test_location_maps_shape():
    maps = build.location_maps()
    assert maps["viridian-forest"] == [("ViridianForest", "", None)]
    assert maps["pewter-city"][1] == ("PewterGym", "Gym", "PEWTER_CITY")
    assert [f for _, f, _ in maps["mt-moon"]] == ["1F", "B1F", "B2F"]


def test_dir_by_type_covers_all_generator_types():
    import generators
    for kind in generators.MAP_TYPES | generators.SCREEN_TYPES | {"battle"}:
        assert kind in build.DIR_BY_TYPE


def test_load_specs_have_required_fields():
    for spec in build.load_specs():
        assert "type" in spec and "name" in spec
        assert spec["type"] in build.DIR_BY_TYPE
