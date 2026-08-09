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
    labels = [label for label, _ in locations.extra_trainer_maps("ss-anne")]
    assert labels == ["SSAnneBow"]
    assert [label for label, _, _ in locations.location_maps()["ss-anne"]] == [
        "SSAnne1F", "SSAnne2F", "SSAnne3F", "SSAnneB1F",
        "SSAnne1FRooms", "SSAnne2FRooms", "SSAnneB1FRooms"]
    assert locations.extra_trainer_maps("route-1") == []
