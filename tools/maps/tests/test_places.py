import places
import sources


def test_kind_reads_the_const_before_the_tileset(root):
    """Oak's Lab and the Fighting Dojo are both drawn with the DOJO tileset, and Saffron Gym
    with the FACILITY one, so the map const is the only witness that tells them apart."""
    assert places.place_kind("OAKS_LAB", "DOJO") == "lab"
    assert places.place_kind("FIGHTING_DOJO", "DOJO") == "dojo"
    assert places.place_kind("SAFFRON_GYM", "FACILITY") == "gym"
    assert places.place_kind("CELADON_HOTEL", "POKECENTER") == "hotel"
    assert places.place_kind("BILLS_HOUSE", "INTERIOR") == "house"
    assert places.place_kind("SILPH_CO_3F", "FACILITY") == "facility"
    assert places.place_kind("VIRIDIAN_FOREST", "FOREST") == "dungeon"


def test_tm_numbers_come_from_the_item_constants(root):
    assert places.tm_display_name(root, "TM_MEGA_DRAIN") == "TM21 Mega Drain"
    assert places.tm_display_name(root, "TM_PSYCHIC_M") == "TM29 Psychic"
    assert places.tm_display_name(root, "HM_SURF") == "HM Surf"


def test_mart_stock_joins_by_the_script_that_names_the_clerk(root):
    marts = places.parse_marts(root)

    assert marts["VIRIDIAN_MART"][0] == "POKE_BALL"
    assert "REPEL" in marts["CERULEAN_MART"]
    # 2F has two counters, and the floor sells what both of them stock
    assert "TM_MEGA_PUNCH" in marts["CELADON_MART_2F"]
    assert "GREAT_BALL" in marts["CELADON_MART_2F"]


def test_gifts_read_both_forms_of_give_pokemon(root):
    gifts = places.parse_gifts(root)

    assert gifts["CELADON_MANSION_ROOF_HOUSE"]["mon"] == (("EEVEE", 25, False),)
    assert gifts["SILPH_CO_7F"]["mon"] == (("LAPRAS", 15, False),)
    # the Dojo picks its species at runtime, so the level sits apart from the species
    assert gifts["FIGHTING_DOJO"]["mon"] == (("HITMONLEE", 30, False), ("HITMONCHAN", 30, False))


def test_the_magikarp_salesman_is_not_a_gift(root):
    """Mt. Moon's Magikarp goes through the same GivePokemon call as a free Eevee; only the
    wallet check in front of it says you are being sold one."""
    (_mon, _level, sold), = places.parse_gifts(root)["MT_MOON_POKECENTER"]["mon"]

    assert sold is True


def test_gift_items_carry_their_quantity(root):
    items = dict(places.parse_gifts(root)["OAKS_LAB"]["item"])

    assert items["POKE_BALL"] == 5
    assert dict(places.parse_gifts(root)["BILLS_HOUSE"]["item"])["S_S_TICKET"] == 1


def test_gym_facts_name_the_leader_the_map_lists_first(root):
    objects = sources.parse_object_events(root, "CeladonGym", include_battlers=True)
    facts = places.gym_facts(root, "CeladonGym", objects)

    assert facts == {"badge": "Rainbow", "tm": "TM21 Mega Drain", "leader": "Erika",
                     "types": ["Grass"]}


def test_gym_types_are_the_ones_the_whole_team_shares(root):
    """Brock fields nothing but Rock/Ground and Yellow's Koga nothing but Bug/Poison, so a
    single "the" type would have to invent a winner where the party states two."""
    built = places.build_places(root)

    assert built["PEWTER_GYM"]["gym"]["types"] == ["Rock", "Ground"]
    assert built["FUCHSIA_GYM"]["gym"]["types"] == ["Bug", "Poison"]
    assert built["VERMILION_GYM"]["gym"]["leader"] == "Lt. Surge"


def test_a_team_with_nothing_in_common_falls_back_to_its_commonest_type(root):
    """No gym leader fields a party this ragged, but a plain trainer does (two Rattata and a
    Zubat share no type at all), and the answer still has to be one type you prepare for."""
    youngster = {"opp_class": "YOUNGSTER", "party": 3}

    assert places._party_types(root, youngster) == ["Normal"]


def test_a_room_with_no_trainer_object_states_no_gym_facts(root):
    assert places.gym_facts(root, "CeladonGym", ()) is None


def test_build_places_skips_the_overworld_and_counts_what_is_inside(root):
    built = places.build_places(root)

    assert "PALLET_TOWN" not in built, "a town is not a place you walk into"
    assert built["OAKS_LAB"] == {"kind": "lab", "trainers": 1,
                                 "gift_item": [{"name": "Poké Ball", "qty": 5}]}
    # 8 trainer objects stand in Celadon Gym, and one of them is Erika herself
    assert built["CELADON_GYM"]["trainers"] == 7
    assert built["CELADON_MANSION_ROOF_HOUSE"]["gift_mon"] == [
        {"dex": "133", "level": 25, "sold": False}]


def test_a_gym_does_not_repeat_its_own_tm_as_a_gift(root):
    built = places.build_places(root)

    assert "gift_item" not in built["FUCHSIA_GYM"]
    assert built["FUCHSIA_GYM"]["gym"]["tm"] == "TM06 Toxic"
