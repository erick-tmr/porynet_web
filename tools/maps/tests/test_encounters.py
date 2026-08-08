import encounters

# Mt. Moon is the load-bearing case: three floors that disagree on both the cast and the odds.
# Sandshrew is on 1F alone, Paras is on B1F/B2F but never 1F, and Clefairy climbs 1.2 -> 5.5 ->
# 10.5. Pinning all three floors at once pins the slot weighting, the per-map parse and the
# aggregation of a species that holds several slots.
MT_MOON = {
    "1F": [("ZUBAT", 74.2, 6, 11), ("GEODUDE", 20.3, 10, 10),
           ("SANDSHREW", 4.3, 12, 12), ("CLEFAIRY", 1.2, 11, 11)],
    "B1F": [("ZUBAT", 64.8, 8, 11), ("GEODUDE", 19.5, 10, 11),
            ("PARAS", 10.2, 9, 11), ("CLEFAIRY", 5.5, 10, 12)],
    "B2F": [("ZUBAT", 54.3, 10, 13), ("GEODUDE", 19.9, 11, 11),
            ("PARAS", 15.2, 13, 13), ("CLEFAIRY", 10.5, 9, 13)],
}


def built(root):
    if not hasattr(built, "cache"):
        built.cache = encounters.build_encounters(root)
    return built.cache


def test_slot_weights_are_the_games_own_and_total_one_encounter(root):
    weights = encounters.slot_weights(root)
    assert weights == [51, 51, 39, 25, 25, 25, 13, 13, 11, 3]
    assert sum(weights) == encounters.SLOT_TOTAL


def test_mt_moon_reproduces_every_floor(root):
    floors = {p["floor"]: p for p in built(root)["mt-moon"]}
    assert list(floors) == ["1F", "B1F", "B2F"]
    for floor, expected in MT_MOON.items():
        got = [(m["species"], m["rate"], m["min_level"], m["max_level"])
               for m in floors[floor]["mons"]]
        assert got == expected, floor


def test_a_species_rate_is_the_sum_of_its_slots_not_ten_percent_each(root):
    """Zubat holds six of 1F's ten slots. A naive 10%-a-slot reading would call that 60%; the
    real weighting makes it 74.2%, and that gap is the whole reason this module exists."""
    zubat = built(root)["mt-moon"][0]["mons"][0]
    assert zubat["species"] == "ZUBAT"
    assert zubat["slots"] == 6
    assert zubat["rate"] == 74.2


def test_rows_carry_the_zero_padded_dex_the_walkthrough_keys_on(root):
    by_species = {m["species"]: m for m in built(root)["mt-moon"][0]["mons"]}
    assert by_species["ZUBAT"]["dex"] == "041"
    assert by_species["CLEFAIRY"]["dex"] == "035"
    assert by_species["SANDSHREW"]["dex"] == "027"


def test_every_floors_rates_sum_to_one_whole_encounter(root):
    """Every map's species shares must add up to 100%, or a slot was dropped or double counted."""
    for slug, places in built(root).items():
        for place in places:
            total = sum(m["rate"] for m in place["mons"])
            assert abs(total - 100) < 0.5, f"{slug} {place['floor']} {place['kind']} = {total}"


def test_every_method_on_a_floor_stays_its_own_place(root):
    """Seafoam B3F is walked, Surfed and fished, and the three disagree about who lives there, so
    they must not be merged into one place."""
    b3f = {p["kind"]: p for p in built(root)["seafoam-islands"] if p["floor"] == "B3F"}
    assert list(b3f) == ["grass", "water", "old_rod", "good_rod", "super_rod"]
    assert {m["species"] for m in b3f["water"]["mons"]} == {"TENTACOOL", "STARYU"}
    assert {m["species"] for m in b3f["super_rod"]["mons"]} == {"KRABBY", "STARYU", "KINGLER"}


def test_the_super_rod_is_weighted_not_a_flat_quarter_per_slot(root):
    """Fuchsia's four slots are Magikarp, Magikarp, Magikarp, Gyarados. A flat quarter each would
    make Gyarados 25%; the real cut points make it the 10.5% prize it is."""
    fuchsia = {p["kind"]: p for p in built(root)["fuchsia-city"]}
    rows = {m["species"]: m for m in fuchsia["super_rod"]["mons"]}
    assert rows["MAGIKARP"]["rate"] == 89.5
    assert rows["GYARADOS"]["rate"] == 10.5
    assert sum(encounters.SUPER_ROD_SLOTS) == encounters.SLOT_TOTAL


def test_the_rods_with_no_map_table_are_the_same_everywhere_there_is_water(root):
    """The Old and Good Rods read no per-map table, so every fishable map offers the same pair."""
    built_maps = built(root)
    for slug in ("fuchsia-city", "route-21", "cerulean-city"):
        by_kind = {p["kind"]: p for p in built_maps[slug]}
        assert [(m["species"], m["rate"]) for m in by_kind["old_rod"]["mons"]] == [("MAGIKARP", 100.0)]
        assert sorted((m["species"], m["rate"]) for m in by_kind["good_rod"]["mons"]) == [
            ("GOLDEEN", 50.0), ("POLIWAG", 50.0)]


def test_a_map_with_no_water_is_offered_no_rod(root):
    """Pewter has neither a water table nor a Super Rod entry, so nothing to cast into."""
    pewter = {p["kind"] for p in built(root).get("pewter-city", [])}
    assert not pewter & set(encounters.ROD_KINDS)
    assert "old_rod" in {p["kind"] for p in built(root)["route-21"]}


def test_a_map_with_no_wild_table_is_absent_rather_than_empty(root):
    """The Rocket Hideout has four floors and no wild Pokemon at all, so it never appears; Silph
    Co. and the S.S. Anne are the same. Presence means "there is something to catch here"."""
    built_maps = built(root)
    for slug in ("rocket-hideout", "silph-co", "ss-anne"):
        assert slug not in built_maps
    assert "mt-moon" in built_maps
