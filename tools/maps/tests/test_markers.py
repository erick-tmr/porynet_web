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


def test_label_alignment_flips_past_the_threshold(root):
    entries = build(root)
    assert all(m["align"] == ("l" if m["x"] > markers.LABEL_FLIP_PCT else "r") for m in entries)
    assert {m["align"] for m in entries} == {"l", "r"}


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
