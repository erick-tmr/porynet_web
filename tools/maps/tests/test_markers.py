import markers

# ViridianForest is 17x24 blocks, so 544x768 px and a 34x48 grid.
VF = ("ViridianForest", "VIRIDIAN_FOREST", 544, 768)


def build(root):
    return markers.build_markers(root, *VF)


def by_cat(entries, cat):
    return [m for m in entries if m["cat"] == cat]


def test_key_letters():
    assert markers.key_letters(0) == "A"
    assert markers.key_letters(4) == "E"
    assert markers.key_letters(25) == "Z"
    assert markers.key_letters(26) == "AA"
    assert markers.key_letters(27) == "AB"
    assert markers.key_letters(51) == "AZ"
    assert markers.key_letters(52) == "BA"


def test_cell_percent_centers_the_cell():
    assert markers.cell_percent(0, 0, 544, 768) == (1.471, 1.042)
    assert markers.cell_percent(16, 42, 544, 768) == (48.529, 88.542)


def test_map_edge():
    assert markers.map_edge(5, 0, 34, 48) == "north"
    assert markers.map_edge(5, 47, 34, 48) == "south"
    assert markers.map_edge(0, 5, 34, 48) == "west"
    assert markers.map_edge(33, 5, 34, 48) == "east"
    assert markers.map_edge(5, 5, 34, 48) == "inner"


def test_group_warps_collapses_a_gate():
    """Four adjacent tiles into one destination is one doorway, not four."""
    warps = ((15, 47, "SOUTH", 2), (16, 47, "SOUTH", 2), (17, 47, "SOUTH", 2), (18, 47, "SOUTH", 2))
    groups = markers.group_warps(warps)
    assert len(groups) == 1
    assert groups[0]["anchor"] == (15, 47)
    assert groups[0]["center"] == (16.5, 47.0)


def test_group_warps_separates_destinations():
    warps = ((1, 0, "NORTH", 3), (2, 0, "NORTH", 3), (15, 47, "SOUTH", 2))
    assert len(markers.group_warps(warps)) == 2


def test_group_warps_joins_through_a_later_cell():
    """The middle tile arrives last, so a greedy first-match pass would leave three groups."""
    warps = ((5, 0, "GATE", 1), (7, 0, "GATE", 1), (6, 0, "GATE", 1))
    groups = markers.group_warps(warps)
    assert len(groups) == 1
    assert groups[0]["anchor"] == (5, 0)


def test_viridian_forest_marker_counts(root):
    entries = build(root)
    assert len(entries) == 12
    assert len(by_cat(entries, "trainer")) == 5
    assert len(by_cat(entries, "item")) == 3
    assert len(by_cat(entries, "hidden")) == 2
    assert len(by_cat(entries, "exit")) == 2


def test_viridian_forest_trainers_are_lettered_in_declaration_order(root):
    trainers = by_cat(build(root), "trainer")
    assert [t["key"] for t in trainers] == ["A", "B", "C", "D", "E"]
    assert [t["ref"] for t in trainers] == [
        "BUG_CATCHER:1", "BUG_CATCHER:2", "BUG_CATCHER:3", "LASS:19", "BUG_CATCHER:15"]
    assert trainers[3]["name"] == "Lass"
    assert trainers[0]["name"] == "Bug Catcher"


def test_viridian_forest_items(root):
    items = by_cat(build(root), "item")
    assert {i["name"] for i in items} == {"Potion", "Poké Ball"}
    assert all(i["key"] is None for i in items)


def test_viridian_forest_hidden_item_position(root):
    antidote = next(m for m in by_cat(build(root), "hidden") if m["name"] == "Antidote")
    assert antidote["id"] == "hidden-16-42"
    assert (antidote["x"], antidote["y"]) == (48.529, 88.542)


def test_viridian_forest_exits(root):
    exits = by_cat(build(root), "exit")
    south = next(e for e in exits if e["edge"] == "south")
    assert south["id"] == "exit-15-47"          # anchored to the min cell of the four-tile gate
    assert south["x"] == 50.0                   # centred on the map's bottom edge
    assert south["glyph"] == "▼"
    assert south["name"] == "Viridian Forest South Gate"

    north = next(e for e in exits if e["edge"] == "north")
    assert north["glyph"] == "▲"


def test_a_door_always_points_up_wherever_the_building_stands(root):
    """A door is walked up into. Oak's Lab sits in the lower half of Pallet Town, so a rule based
    on which half of the map an exit falls in would send you down into it."""
    doors = [m for m in markers.build_markers(root, "PalletTown", "PALLET_TOWN", 320, 288)
             if m["cat"] == "exit" and m["edge"] == "inner"]

    assert doors, "Pallet Town's houses are all inner doors"
    assert all(d["glyph"] == "▲" for d in doors)
    assert any(d["y"] > 50 for d in doors), "and at least one of them is in the lower half"


def test_exit_glyphs_follow_the_way_you_walk(root):
    for entry in by_cat(build(root), "exit"):
        assert entry["glyph"] == markers.EXIT_GLYPHS[entry["edge"]]


def test_label_alignment_follows_the_marker_side(root):
    entries = build(root)
    assert {m["align"] for m in entries} == {"l", "r"}
    assert all(m["align"] == "l" for m in entries if m["x"] > markers.LABEL_FLIP_PCT)


def test_neighbours_on_one_row_take_separate_lanes(root):
    """The hidden Potion and the Bug Catcher beside it sit one cell apart on the same row, and
    both hug the left edge, so they can only be separated vertically."""
    entries = {m["id"]: m for m in build(root)}
    potion, catcher = entries["hidden-1-18"], entries["trainer-2-18"]

    assert potion["y"] == catcher["y"]
    assert potion["align"] == catcher["align"] == "r"
    assert {potion["lane"], catcher["lane"]} == {0, 1}


def test_every_label_stays_on_the_side_its_marker_is_on(root):
    for entry in build(root):
        assert entry["align"] == ("l" if entry["x"] > markers.LABEL_FLIP_PCT else "r")


def lanes(rows):
    return [e["lane"] for e in markers.assign_label_lanes(rows, 544, 768)]


def row(y, x, name="Potion", align="r"):
    return {"y": y, "x": x, "name": name, "align": align}


def test_lanes_stay_flat_on_a_clear_column():
    assert lanes([ row(10.0, 5), row(80.0, 5) ]) == [ 0, 0 ]


def test_lanes_stay_flat_when_labels_share_a_row_but_sit_far_apart():
    """Same row, opposite ends of the map: the labels never meet, so neither moves."""
    assert lanes([ row(10.0, 2), row(10.0, 55) ]) == [ 0, 0 ]


def test_lanes_keep_stacking_past_two():
    assert lanes([ row(10.0, 5), row(10.1, 6), row(10.2, 7) ]) == [ 0, 1, 2 ]


def test_a_longer_name_reserves_more_room():
    """A short name clears its neighbour; the same pair collides once the name grows."""
    assert lanes([ row(10.0, 2, "TM"), row(10.0, 12) ]) == [ 0, 0 ]
    assert lanes([ row(10.0, 2, "Viridian Forest North Gate"), row(10.0, 12) ]) == [ 0, 1 ]


def test_marker_ids_are_unique(root):
    ids = [m["id"] for m in build(root)]
    assert len(ids) == len(set(ids))


def test_marker_shape_is_complete(root):
    required = {"id", "cat", "key", "name", "x", "y", "grid", "align", "ref"}
    for entry in build(root):
        assert required <= set(entry)
        assert 0 <= entry["x"] <= 100 and 0 <= entry["y"] <= 100


def test_map_with_no_markers(root):
    """A one-room house has a warp and nothing else; it must not blow up."""
    entries = markers.build_markers(root, "RedsHouse2F", "REDS_HOUSE_2F", 128, 128)
    assert [m["cat"] for m in entries] == ["exit"]


def test_connections_become_exits(root):
    """Pallet Town's three doors are warps, but the ways out of town are map connections: north
    to Route 1 and south, by Surf, to Route 21."""
    exits = [m for m in markers.build_markers(root, "PalletTown", "PALLET_TOWN", 320, 288)
             if m["cat"] == "exit"]
    by_id = {m["id"]: m for m in exits}

    assert by_id["exit-north"]["name"] == "Route 1"
    assert by_id["exit-north"]["glyph"] == "▲"
    assert by_id["exit-south"]["name"] == "Route 21"
    assert by_id["exit-south"]["glyph"] == "▼"
    # you leave Pallet Town southward by Surf, so the marker sits on the water rather than on
    # the midpoint of the edge, which is beach
    assert by_id["exit-south"]["grid"] == [6, 17]
    assert len([m for m in exits if m["edge"] == "inner"]) == 3


def test_a_route_that_only_connects_still_has_exits(root):
    """Route 1 has no gates at all; without its connections it would show no way off the map."""
    exits = [m for m in markers.build_markers(root, "Route1", "ROUTE_1", 320, 576)
             if m["cat"] == "exit"]

    assert {m["name"] for m in exits} == {"Viridian City", "Pallet Town"}


def test_the_two_sides_of_a_crossing_agree(root):
    """Pallet Town's way south and Route 21's way north are the same stretch of water."""
    pallet = {m["id"]: m for m in markers.build_markers(root, "PalletTown", "PALLET_TOWN", 320, 288)}
    route21 = {m["id"]: m for m in markers.build_markers(root, "Route21", "ROUTE_21", 320, 1440)}

    assert pallet["exit-south"]["grid"][0] == route21["exit-north"]["grid"][0]


def test_a_dry_edge_uses_the_walkable_span(root):
    """Route 1 has no water; its exits sit where the path leaves the map, not in a corner."""
    exits = [m for m in markers.build_markers(root, "Route1", "ROUTE_1", 320, 576)
             if m["cat"] == "exit"]

    assert all(0 < m["grid"][0] < 19 for m in exits)
