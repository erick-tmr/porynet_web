import markers
import sources

# ViridianForest is 17x24 blocks, so 544x768 px and a 34x48 grid.
VF = ("ViridianForest", "VIRIDIAN_FOREST", 544, 768)


def build(root):
    return markers.build_markers(root, *VF)


def by_cat(entries, cat):
    return [m for m in entries if m["cat"] == cat]


def test_marker_key_prefixes_by_category():
    assert markers.marker_key("trainer", 0) == "T1"
    assert markers.marker_key("item", 1) == "I2"
    assert markers.marker_key("hidden", 2) == "H3"
    assert markers.marker_key("exit", 11) == "E12"
    assert markers.marker_key("npc", 0) == "N1"


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


def test_viridian_forest_trainers_are_numbered_in_declaration_order(root):
    trainers = by_cat(build(root), "trainer")
    assert [t["key"] for t in trainers] == ["T1", "T2", "T3", "T4", "T5"]
    assert [t["ref"] for t in trainers] == [
        "BUG_CATCHER:1", "BUG_CATCHER:2", "BUG_CATCHER:3", "LASS:19", "BUG_CATCHER:15"]
    assert trainers[3]["name"] == "Lass"
    assert trainers[0]["name"] == "Bug Catcher"


def test_viridian_forest_items(root):
    items = by_cat(build(root), "item")
    assert {i["name"] for i in items} == {"Potion", "Poké Ball"}
    assert [i["key"] for i in items] == ["I1", "I2", "I3"]


def test_every_marker_is_keyed_and_each_category_counts_from_one(root):
    """A key names its own kind, so no legend row is left without a handle and adding an item ball
    can never renumber a trainer."""
    entries = build(root)
    assert [m["key"] for m in entries] == [
        "T1", "T2", "T3", "T4", "T5", "I1", "I2", "I3", "H1", "H2", "E1", "E2"]


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


def cerulean_exits(root):
    return [m for m in markers.build_markers(root, "CeruleanCity", "CERULEAN_CITY", 640, 576)
            if m["cat"] == "exit"]


def test_a_pass_through_house_splits_into_an_enter_and_a_back_exit(root):
    """The Badge House and Trashed House each warp to one interior through a front door and a
    door behind, so both would otherwise print the same name twice. The door facing the street
    (larger grid y) is the entrance; the one behind it is the back exit."""
    by_name = {m["name"]: m for m in cerulean_exits(root)}
    for house in ("Trashed House", "Badge House"):
        assert by_name[f"{house} (enter)"]["grid"][1] > by_name[f"{house} (exit)"]["grid"][1]


def test_the_split_generalises_to_every_town_and_the_route_gates(root):
    """Not a Cerulean special case: Celadon Mansion, the Fuchsia cut-through and the Route 12 gate
    are all walk-throughs, so they split the same way."""
    celadon = [m["name"] for m in markers.build_markers(root, "CeladonCity", "CELADON_CITY", 640, 576)
               if m["cat"] == "exit"]
    assert "Mansion 1F (enter)" in celadon and "Mansion 1F (exit)" in celadon


def test_lone_pass_through_door_is_left_unlabelled():
    """The split only fires on the two-door pair; a single door keeps its plain name."""
    one = [{"name": "Cerulean Trashed House", "ref": "CERULEAN_TRASHED_HOUSE", "grid": [27, 11]}]
    markers.label_pass_through_doors(one)
    assert one[0]["name"] == "Cerulean Trashed House"


def test_far_apart_same_column_doors_are_not_a_pass_through():
    """Two mouths of a cave in the same column but far apart are separate exits, not one house."""
    doors = [{"name": "Rock Tunnel", "ref": "ROCK_TUNNEL_1F", "grid": [8, 17]},
             {"name": "Rock Tunnel", "ref": "ROCK_TUNNEL_1F", "grid": [8, 53]}]
    markers.label_pass_through_doors(doors)
    assert [d["name"] for d in doors] == ["Rock Tunnel", "Rock Tunnel"]


def test_side_by_side_doors_are_not_a_pass_through():
    """A front door and back door share a column; two doors on the same row are a wide entrance."""
    doors = [{"name": "Mart", "ref": "MART", "grid": [4, 9]},
             {"name": "Mart", "ref": "MART", "grid": [9, 9]}]
    markers.label_pass_through_doors(doors)
    assert all(d["name"] == "Mart" for d in doors)


def test_a_town_map_drops_the_redundant_town_name_from_its_doorways(root):
    """On the Cerulean map 'Cerulean Gym' is just 'Gym'; the prefix only crowds the label layer.
    The routes it connects to keep their full names."""
    names = [m["name"] for m in cerulean_exits(root)]
    assert {"Gym", "Pokecenter", "Cave 1F"} <= set(names)
    assert not any(name.startswith("Cerulean ") for name in names)
    assert "Route 24" in names


def test_strip_town_prefix_leaves_non_town_maps_alone():
    exits = [{"name": "Route 2 Gate"}]
    markers.strip_town_prefix(exits, "ROUTE_2")
    assert exits[0]["name"] == "Route 2 Gate"


def test_a_road_across_a_pond_anchors_to_the_road_not_the_water(root):
    """Cerulean's pond touches its north and west edges, so the generic 'water is crossed by Surf'
    rule would drop the Route 24 and Route 4 markers on the water. They belong on the Nugget Bridge
    and the road instead."""
    exits = {m["ref"]: tuple(m["grid"]) for m in cerulean_exits(root)}
    assert exits["ROUTE_24"] == (20, 0)   # the bridge, not the pond around x14-18
    assert exits["ROUTE_4"] == (0, 18)    # the road, not the pond at y15-16


def test_route_6_south_exit_anchors_to_the_road_not_the_pond(root):
    """Route 6's decorative pond touches its south edge, so the generic 'water is crossed by Surf'
    rule dropped the Vermilion City marker on the pond (cell 6). It belongs on the road out (cell 9)."""
    south = next(m for m in markers.build_markers(root, "Route6", "ROUTE_6", 320, 576)
                 if m.get("edge") == "south")
    assert south["ref"] == "VERMILION_CITY"
    assert tuple(south["grid"]) == (9, 35)
    tsf = sources.tileset_basename(root, "OVERWORLD")
    tiles = sources.cell_tiles(root, "Route6", tsf, 320 // sources.BLOCK_PX, *south["grid"])
    assert not all(t in sources.WATER_TILES for t in tiles), "on the road, not the pond"


def test_a_surf_connection_still_lands_on_water(root):
    """The land-road override is scoped: Pallet's genuine Surf crossing south to Route 21 keeps its
    water marker."""
    tsf = sources.tileset_basename(root, "OVERWORLD")
    south = next(m for m in markers.build_markers(root, "PalletTown", "PALLET_TOWN", 320, 288)
                 if m.get("edge") == "south")
    gx, gy = south["grid"]
    tiles = sources.cell_tiles(root, "PalletTown", tsf, 320 // sources.BLOCK_PX, gx, gy)
    assert all(t in sources.WATER_TILES for t in tiles)


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


def settled(rows, height_px=768):
    """Where each label ends up down the map, in percent, once its lane is applied."""
    row_pct = markers.LABEL_PX / height_px * 100
    return [e["y"] + e["lane"] * row_pct for e in markers.assign_label_lanes(rows, 544, height_px)]


def test_a_label_is_measured_where_it_lands_not_by_the_lane_it_is_filed_under():
    """Four markers a fraction of a row apart, the shape Route 8's column of Lasses makes. Counting
    clashes lane by lane they came out 1, 2, 0, 1: no two shared a lane number, so each read as
    settled, and every one of them still printed over the label above or below it."""
    ends = settled([ row(10.0, 5), row(11.0, 5), row(12.0, 5), row(13.0, 5) ])
    row_pct = markers.LABEL_PX / 768 * 100

    assert len(ends) == 4
    assert all(abs(a - b) + markers.LANE_EPSILON >= row_pct
               for i, a in enumerate(ends) for b in ends[i + 1:])


def test_a_crowd_opens_both_ways_rather_than_cascading_down():
    """Four labels stacked on one spot open outward from it, taking the row below, the next one
    below, then the second row above. Dealt downward only they march off the bottom of the map
    instead, which is how a page ends up with a name printed past its own picture."""
    assert lanes([ row(50.0, 5), row(50.1, 5), row(50.2, 5), row(50.3, 5) ]) == [ 0, 1, 2, -2 ]


def test_no_label_is_dealt_off_the_map():
    assert list(markers.lane_seats(0.0, 20.0)) == [ 0, 1, 2, 3, 4, 5 ]
    assert list(markers.lane_seats(100.0, 20.0)) == [ 0, -1, -2, -3, -4, -5 ]
    assert list(markers.lane_seats(50.0, 60.0)) == [ 0 ]


def test_a_label_with_nowhere_clean_to_go_takes_the_row_it_covers_least():
    """Past its reach a label stops looking, so a map too crowded to lay out cleanly still keeps
    every label within a leader line of its own pin."""
    crowd = [ row(50.0 + n / 100, 5) for n in range(2 * markers.LABEL_LANE_REACH + 4) ]

    assert all(abs(e["lane"]) <= markers.LABEL_LANE_REACH
               for e in markers.assign_label_lanes(crowd, 544, 768))


def test_a_longer_name_reserves_more_room():
    """A short name clears its neighbour; the same pair collides once the name grows."""
    assert lanes([ row(10.0, 2, "TM"), row(10.0, 12) ]) == [ 0, 0 ]
    assert lanes([ row(10.0, 2, "Viridian Forest North Gate"), row(10.0, 12) ]) == [ 0, 1 ]


def test_a_narrow_map_measures_labels_against_the_width_it_is_drawn_at():
    label = row(10.0, 40, "Underground Path Route 5")

    assert markers.drawn_width(640) == 640
    assert markers.drawn_width(128) == markers.NARROW_MAP_DRAWN_PX
    assert markers.label_span(label, 128) == markers.label_span(label, 320)
    assert markers.label_span(label, 320) != markers.label_span(label, 640)


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


def test_a_connection_exit_lands_on_the_strip_it_shares_not_a_far_corner(root):
    """Regression: Viridian City's west edge opens in more than one place, but Route 22 only
    connects along the strip the header offsets it to (`connection west, Route22, ROUTE_22, 4`,
    so blocks 4..12, cells 8..25). The exit used to land at the far bottom corner (cell 30);
    it belongs on the shared strip, near its middle."""
    viridian = {m["id"]: m for m in
                markers.build_markers(root, "ViridianCity", "VIRIDIAN_CITY", 640, 576)}
    west = viridian["exit-west"]

    assert (west["name"], west["edge"]) == ("Route 22", "west")
    assert 8 <= west["grid"][1] <= 25, "the Route 22 exit sits on the strip Route 22 shares"


def test_cell_is_walkable_tells_grass_from_trees(root):
    """Viridian Forest is 17 blocks wide: the Potion tile is grass you can stand on, the tree
    column at the very edge is not."""
    assert markers.cell_is_walkable(root, "ViridianForest", "FOREST", 17, (1, 18))
    assert not markers.cell_is_walkable(root, "ViridianForest", "FOREST", 17, (0, 18))


def test_cell_is_standable_rejects_a_hedge_row_cell_is_land_would_pass(root):
    """Route 3's [19, 7] is open across its top (grass) but its lower-left tile is the hedge
    beneath, the exact tile the game stands you on. cell_is_land passes it (some sub-tile is open),
    so a sprite planted there straddles the hedge; cell_is_standable rejects it as the game would."""
    const, tileset = sources.parse_headers(root)["Route3"]
    width = sources.parse_map_constants(root)[0][const][1]
    assert markers.cell_is_land(root, "Route3", tileset, width, (19, 7)), "top is open, so 'land'"
    assert not markers.cell_is_standable(root, "Route3", tileset, width, (19, 7)), "feet on the hedge"
    assert markers.cell_is_standable(root, "Route3", tileset, width, (19, 6)), "the grass a row up is clean"


def test_cell_is_standable_accepts_an_interior_floor(root):
    """An interior floor cell's lower-left is the walkable tile even when its lower-right is a
    decorative shadow, so the follower still stands on a Poke Center / gate floor."""
    const, tileset = sources.parse_headers(root)["PewterPokecenter"]
    width = sources.parse_map_constants(root)[0][const][1]
    assert markers.cell_is_standable(root, "PewterPokecenter", tileset, width, (2, 3))


def test_connection_span_narrows_an_edge_to_the_shared_strip():
    """A west edge, a neighbour 9 blocks tall offset 2 blocks: the strip is cells 4..21, the
    neighbour's own height of cells (18) starting two blocks (4 cells) down."""
    edge = markers.edge_cells("west", 20, 30)
    strip = markers.connection_span(edge, "west", 2, (0, 5, 9), 20, 30)

    assert strip[0] == (0, 4) and strip[-1] == (0, 21)
    assert markers.connection_span(edge, "west", 2, None, 20, 30) == edge  # unknown dims: whole edge


def test_link_exit_keys_gives_both_ends_of_a_staircase_one_key(root):
    """Mt. Moon 1F's three doors all read 'Mt. Moon B1F'; the shared key is what says which of B1F's
    doors each one lands on. The game names the target slot, so the pairing is read, not guessed."""
    headers = sources.parse_headers(root)
    floors = [("MtMoon1F", "mt-moon-1f", 640, 720), ("MtMoonB1F", "mt-moon-b1f", 640, 576),
              ("MtMoonB2F", "mt-moon-b2f", 640, 576)]
    entries, labels, warps, consts = [], [], {}, {}
    for label, name, w, h in floors:
        entries.append({"name": name,
                        "markers": markers.build_markers(root, label, headers[label][0], w, h)})
        labels.append(label)
        warps[label] = sources.parse_warp_events(root, label)
        consts[label] = headers[label][0]

    markers.link_exit_keys(entries, labels, warps, consts)
    keys = {e["name"]: {m["id"]: m["key"] for m in e["markers"] if m["cat"] == "exit"}
            for e in entries}

    assert keys["mt-moon-1f"]["exit-5-5"] == keys["mt-moon-b1f"]["exit-5-5"]
    assert keys["mt-moon-1f"]["exit-17-11"] == keys["mt-moon-b1f"]["exit-25-9"]
    assert keys["mt-moon-b1f"]["exit-13-27"] == keys["mt-moon-b2f"]["exit-15-27"]
    # the two mouths onto Route 3 and Route 4 have no twin here, so they keep keys of their own
    outside = [keys["mt-moon-1f"]["exit-14-35"], keys["mt-moon-b1f"]["exit-27-3"]]
    assert len(set(outside)) == 2


def test_the_underground_path_pins_both_hidden_items_and_both_staircases(root):
    entries = markers.build_markers(root, "UndergroundPathNorthSouth",
                                    "UNDERGROUND_PATH_NORTH_SOUTH", 128, 736)
    by_id = {m["id"]: m for m in entries}

    assert [(m["key"], m["name"], m["grid"]) for m in by_cat(entries, "hidden")] == [
        ("H1", "Full Restore", [3, 4]), ("H2", "X Special", [4, 34])]
    assert by_id["exit-5-4"]["name"] == "Underground Path Route 5"
    assert by_id["exit-2-41"]["name"] == "Underground Path Route 6"
    assert len(entries) == 4, "no trainers and no item balls live down there"


def test_a_cave_mouth_draws_one_doorway_not_its_edge_bounce_spare(root):
    """Rock Tunnel 1F lists four warps back outside, and only two are doors. Beside each ladder the
    game keeps a spare pointing at the same warp slot a few cells into the rock, so walking off the
    map edge bounces you out; (15, 0) is sealed in a three-cell pocket and (15, 35) is not even a
    tile you can stand on. Both used to draw a second "Back outside" pin on solid stone."""
    warps = sources.parse_warp_events(root, "RockTunnel1F")
    outside = [w for w in warps if w[2] == "LAST_MAP"]
    doors = {g["anchor"] for g in markers.group_warps(warps) if g["dest"] == "LAST_MAP"}

    assert len(outside) == 4, "the game writes four warps back outside"
    assert doors == {(15, 3), (15, 33)}, "only the two ladders are doorways"


def test_two_real_doors_sharing_an_outdoor_tile_both_survive(root):
    """The spare rule keys off distance, not just the shared destination slot: the Pokemon Mansion
    leaves by two separate south exits that drop you on Cinnabar's single mansion tile, and twenty
    cells apart they are two doors a reader has to be able to tell apart."""
    groups = markers.group_warps(sources.parse_warp_events(root, "PokemonMansion1F"))
    out = sorted(g["anchor"] for g in groups if g["dest"] == "LAST_MAP")

    assert len(out) == 2, "both south exits keep their pin"
    assert abs(out[0][0] - out[1][0]) > markers.SPARE_WARP_REACH
