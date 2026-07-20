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
    """Maps a location owns but never draws, whose trainers still belong to it."""
    labels = [label for label, _ in locations.extra_trainer_maps("ss-anne")]
    assert labels == ["SSAnne1FRooms", "SSAnne2FRooms", "SSAnneB1FRooms", "SSAnneBow"]
    assert locations.extra_trainer_maps("route-1") == []
