import build


def test_dir_by_type_covers_all_generator_types():
    import generators
    for kind in generators.MAP_TYPES | generators.SCREEN_TYPES | {"battle"}:
        assert kind in build.DIR_BY_TYPE


def test_load_specs_have_required_fields():
    for spec in build.load_specs():
        assert "type" in spec and "name" in spec
        assert spec["type"] in build.DIR_BY_TYPE


def test_a_step_frame_is_indexed_by_name_as_well_as_by_step():
    """The (slug, step) index is positional and breaks the moment a location's steps are
    renumbered. Every frame must therefore also be reachable by its own name, which is what a
    step's `scene:` points at."""
    scenes, step_shots = {}, {}
    spec = {"type": "screen", "name": "mt-moon-fossils", "slug": "mt-moon", "step": 4}
    build.file_frame(scenes, step_shots, spec, spec["name"], {"image": "a.png"})

    assert scenes["mt-moon-fossils"]["image"] == "a.png"
    assert scenes["mt-moon-fossils"]["type"] == "screen"
    assert step_shots["mt-moon"]["4"]["image"] == "a.png"


def test_a_frame_with_no_step_is_filed_under_scenes_alone():
    scenes, step_shots = {}, {}
    build.file_frame(scenes, step_shots, {"type": "battle", "name": "battle-misty"},
                     "battle-misty", {"image": "b.png"})

    assert "battle-misty" in scenes
    assert step_shots == {}


def test_step_zero_is_indexed_rather_than_treated_as_absent():
    """`spec["step"]` is checked against None, not truthiness, so a step 0 still indexes."""
    scenes, step_shots = {}, {}
    build.file_frame(scenes, step_shots, {"type": "screen", "slug": "s", "step": 0}, "n", {})

    assert step_shots["s"]["0"] == {}
