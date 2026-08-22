import locations


def test_image_name_floors():
    assert locations.image_name("mt-moon", "") == "mt-moon"
    assert locations.image_name("mt-moon", "B1F") == "mt-moon-b1f"
    assert locations.image_name("safari-zone", "Center") == "safari-zone-center"


def test_location_maps_shape():
    maps = locations.location_maps()
    assert maps["viridian-forest"] == [("ViridianForest", "", None)]
    assert maps["pewter-city"][1] == ("PewterGym", "Gym", "PEWTER_CITY")
    assert [f for _, f, _ in maps["mt-moon"]] == ["1F", "B1F", "B2F"]


def test_extra_trainer_maps():
    """Maps a location owns but never draws, whose trainers still belong to it.

    The three cabin *Rooms maps used to live here. They are drawn now, so they moved to _DUNGEONS;
    a map listed in both would have its trainers counted twice, since roster.py walks this list
    separately from location_maps."""
    assert [label for label, _, _ in locations.extra_trainer_maps("saffron-city")] == ["FightingDojo"]
    # the arcade's Rocket rosters with the hideout, named by his room rather than a floor
    assert locations.extra_trainer_maps("rocket-hideout") == [
        ("GameCorner", "CELADON_CITY", "Game Corner")
    ]
    assert locations.extra_trainer_maps("celadon-city") == [], "the town no longer carries him"
    assert locations.extra_trainer_maps("ss-anne") == [], "the bow is drawn now, not just walked"
    assert locations.extra_trainer_maps("route-1") == []


def test_the_ship_draws_one_map_per_deck_in_the_order_it_is_walked():
    """Four decks, not nine floors. The cabins, the kitchen and the bow are drawn into the deck
    they open off (decks.py), so nobody has to match a corridor of identical doors against a grid
    of identical cabins by letter.

    They come out in the order the guide boards them rather than the order the ship is stacked:
    you step aboard on 1F and go straight below, so the crew deck is the second map on the page and
    the second run of trainer cards under it."""
    assert [label for label, _, _ in locations.location_maps()["ss-anne"]] == [
        "SSAnne1F", "SSAnneB1F", "SSAnne2F", "SSAnne3F"]


def test_every_attached_room_hangs_off_a_map_that_is_drawn():
    """An attached room is drawn into another map's image and nowhere else, so its corridor has to
    be a floor the location really draws. Attach one to a map nobody draws and the room, its items
    and its trainers drop off the site silently."""
    drawn = {label for maps in locations.location_maps().values() for label, _, _ in maps}
    attached = {"SSAnne1F", "SSAnne2F", "SSAnne3F", "SSAnneB1F"}

    assert attached <= drawn
    for corridor in attached:
        assert locations.attached(corridor), f"{corridor} is a deck and should carry its rooms"
    assert locations.attached("Route1") == [], "a plain map has nothing hung off it"
