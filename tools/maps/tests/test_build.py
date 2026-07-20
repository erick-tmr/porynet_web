import build


def test_dir_by_type_covers_all_generator_types():
    import generators
    for kind in generators.MAP_TYPES | generators.SCREEN_TYPES | {"battle"}:
        assert kind in build.DIR_BY_TYPE


def test_load_specs_have_required_fields():
    for spec in build.load_specs():
        assert "type" in spec and "name" in spec
        assert spec["type"] in build.DIR_BY_TYPE
