"""A deck is a corridor drawn with the rooms you reach from it (decks.py).

The failure these guard against is silent: a crop that clips a cabin, a room hung off the wrong
door, or a connector drawn to the wrong place all render a perfectly plausible picture. So the
tests check the decision rather than the pixels, against the game's own data.
"""
import decks
import locations
import markers
import sources

SHIP = [("SSAnne1F", "1F"), ("SSAnne2F", "2F"), ("SSAnne3F", "3F"), ("SSAnneB1F", "B1F")]


def _plan(root, corridor, floor):
    return decks.plan(root, corridor, floor, locations.attached(corridor))


def _rect(place):
    return (place.origin[0], place.origin[1],
            place.origin[0] + (place.cells[2] - place.cells[0]) * decks.CELL,
            place.origin[1] + (place.cells[3] - place.cells[1]) * decks.CELL)


def test_a_shared_rooms_map_crops_to_the_one_cabin_you_walked_into(root):
    """SS_ANNE_1F_ROOMS is six cabins in a 3x2 grid with the border block flooded between them.
    Each of 1F's six doors has to come back with its own 4x6 cabin, never two of them at once."""
    deck = _plan(root, "SSAnne1F", "1F")
    cabins = [p.cells for p in deck.placements if p.label == "SSAnne1FRooms"]

    assert len(cabins) == 6 and len(set(cabins)) == 6, "one distinct cabin per door"
    assert all((x1 - x0, y1 - y0) == (4, 6) for x0, y0, x1, y1 in cabins)
    assert sorted(cabins) == [(0, 0, 4, 6), (0, 10, 4, 16), (10, 0, 14, 6),
                              (10, 10, 14, 16), (20, 0, 24, 6), (20, 10, 24, 16)]


def test_a_room_with_nothing_flooded_between_comes_back_whole(root):
    """The kitchen is one room filling its map, so the flood fill has nothing to cut and the crop
    is the map. Clipping it would drop the Great Ball buried in its last bin."""
    kitchen = next(p for p in _plan(root, "SSAnne1F", "1F").placements
                   if p.label == "SSAnneKitchen")

    assert kitchen.cells == (0, 0, *markers.map_cells(root, "SS_ANNE_KITCHEN"))


def test_which_side_a_room_lies_on_comes_out_of_the_collision_data(root):
    """1F's doors are in the corridor's south wall so its cabins hang below; 2F's and B1F's are in
    the north wall so theirs sit above; 3F leaves west onto the bow. Nothing here is configured:
    the open tile beside a doorway is the one you stand on, so the room is on the other side."""
    sides = {corridor: {decks.room_side(root, corridor, door["anchor"])
                        for door in markers.group_warps(sources.parse_warp_events(root, corridor))
                        if door["dest"] in
                        {sources.parse_headers(root)[label][0] for label, _ in
                         locations.attached(corridor)}}
             for corridor, _floor in SHIP}

    assert sides == {"SSAnne1F": {"south"}, "SSAnne2F": {"north"},
                     "SSAnne3F": {"west"}, "SSAnneB1F": {"north"}}


def test_every_connector_runs_straight_from_a_door_to_the_room_it_opens(root):
    """A room lines its own doorway up with the corridor's, so a connector is a straight run along
    one axis. A diagonal means a room landed somewhere it does not belong."""
    for corridor, floor in SHIP:
        for start, end in _plan(root, corridor, floor).connectors:
            assert start[0] == end[0] or start[1] == end[1], \
                f"{corridor}: connector {start} -> {end} is not axis-aligned"


def test_nothing_a_deck_draws_overlaps_anything_else_it_draws(root):
    """Rooms fall to the next row out rather than landing on each other or on the corridor, which
    is how 1F's kitchen ends up below its cabins."""
    for corridor, floor in SHIP:
        rects = [_rect(p) for p in _plan(root, corridor, floor).placements]
        for index, (ax0, ay0, ax1, ay1) in enumerate(rects):
            for bx0, by0, bx1, by1 in rects[index + 1:]:
                assert ax1 <= bx0 or bx1 <= ax0 or ay1 <= by0 or by1 <= ay0, \
                    f"{corridor}: {(ax0, ay0, ax1, ay1)} overlaps {(bx0, by0, bx1, by1)}"


def test_a_connector_never_crosses_a_room_it_does_not_lead_to(root):
    """The kitchen sits a row past the cabins, so its connector runs down the deck beside them. A
    line crossing a room it is not for reads as a door into that room."""
    for corridor, floor in SHIP:
        deck = _plan(root, corridor, floor)
        for (start, end), place in zip(deck.connectors, deck.placements[1:], strict=True):
            x0, y0, x1, y1 = _rect(place)
            crossed = [other for other in deck.placements[1:] if other is not place
                       and _crosses(_rect(other), start, end)]
            assert not crossed, \
                f"{corridor}: the connector to {(x0, y0, x1, y1)} crosses {_rect(crossed[0])}"


def _crosses(rect, start, end):
    x0, y0, x1, y1 = rect
    lo_x, hi_x = sorted((start[0], end[0]))
    lo_y, hi_y = sorted((start[1], end[1]))
    return lo_x < x1 and x0 < hi_x and lo_y < y1 and y0 < hi_y


def test_a_deck_numbers_its_pins_once_across_the_corridor_and_every_room(root):
    """The corridor and its rooms are one picture, so they share one run of keys: two T1s on the
    same map would send a card's reader to the wrong pin."""
    pins = decks.area_markers(root, "SSAnne1F", "1F", 0, 0)
    keys = [p["key"] for p in pins]

    assert len(set(keys)) == len(keys)
    assert [p["key"] for p in pins if p["cat"] == "trainer"] == ["T1", "T2", "T3", "T4"]
    assert [p["key"] for p in pins if p["cat"] == "item"] == ["I1"]
    assert [p["key"] for p in pins if p["cat"] == "hidden"] == ["H1"]


def test_a_swept_deck_clears_across_its_rooms_and_inside_them(root):
    """The ship's cabins hang off one corridor and the stairs land you partway along it, so those
    floors are swept from one end rather than nearest-door-first. That has to reach inside a cabin
    too: two trainers share a room on each of them, and a room is far too small for the corridor's
    walk to say which of the pair you meet first. 1F sweeps right to left, 2F the other way."""
    for corridor, floor, reverse in (("SSAnne1F", "1F", True), ("SSAnne2F", "2F", False)):
        deck = decks.plan(root, corridor, floor, locations.attached(corridor))
        doors = [place.door[0] for place in decks.numbered_order(root, deck)[1:] if place.door]
        across = [pin["x"] for pin in decks.area_markers(root, corridor, floor, 0, 0)
                  if pin["cat"] == "trainer"]

        assert doors == sorted(doors, reverse=reverse), f"{corridor}: rooms out of order"
        assert across == sorted(across, reverse=reverse), f"{corridor}: pins out of order"


def test_a_walked_deck_orders_a_cabin_from_its_own_doorway(root):
    """B1F is walked, not swept, so a cabin holding two hands you the one by the door first. The
    map file lists the pair the other way round, and the corridor's walk cannot tell them apart:
    both are through the same door, and it stops at the doorway."""
    room = [pin for pin in decks.area_markers(root, "SSAnneB1F", "B1F", 0, 0)
            if pin["cat"] == "trainer" and pin["key"] in ("T5", "T6")]

    assert [tuple(pin["grid"]) for pin in room] == [(0, 4), (0, 2)]
    assert [pin["ref"] for pin in room] == ["FISHER:2", "SAILOR:7"]


def test_a_deck_numbers_its_rooms_in_the_order_you_pass_their_doors(root):
    """The crew deck runs west from the stairs you come down, so its cabins letter east to west.
    The map file lists those doorways the other way round, and the layout is settled in that order
    too and must not move (rooms are packed into rows as they are staged, so a reshuffle would
    redraw the picture), which is why only the numbering is sorted."""
    deck = decks.plan(root, "SSAnneB1F", "B1F", locations.attached("SSAnneB1F"))
    order = decks.numbered_order(root, deck)
    doors = [place.door for place in order[1:]]

    assert order[0].label == "SSAnneB1F", "the corridor always counts first"
    assert doors == sorted(doors, key=lambda door: -door[0]), "east to west, away from the stairs"
    assert doors != [place.door for place in deck.placements[1:]], \
        "the layout stages them the other way round, and numbering no longer follows it"
    assert sorted(doors) == sorted(place.door for place in deck.placements[1:]), \
        "the same rooms either way: only their order differs"


def test_a_deck_lands_its_cabin_items_in_the_order_the_steps_collect_them(root):
    """What that buys: B1F's five cabins hold four items, and the guide takes them from the cabin
    nearest the stairs outwards. Numbered by the map file they came out backwards, so a reader
    working down the page counted I3, I2, I1."""
    pins = {p["id"]: p["key"] for p in decks.area_markers(root, "SSAnneB1F", "B1F", 0, 0)}

    assert [pins["item-12-11"], pins["item-20-2"], pins["item-10-2"]] == ["I1", "I2", "I3"]


def test_a_rooms_own_door_back_to_the_corridor_is_not_pinned_a_second_time(root):
    """Both ends of that doorway are now on one picture with a connector between them, so the room
    side is dropped: two pins for one door would spend two letters saying the same thing."""
    for corridor, floor in SHIP:
        home = sources.parse_headers(root)[corridor][0]
        refs = [p["ref"] for p in decks.area_markers(root, corridor, floor, 0, 0)
                if p["cat"] == "exit"]

        assert home not in refs, f"{corridor}: a room still pins its own way back"


def test_a_deck_keeps_every_trainer_item_and_hidden_item_its_maps_hold(root):
    """The crop is the risk this whole module carries: a cabin clipped a few cells short still
    renders a plausible room, with an item ball quietly outside the frame. Count what the game
    puts on the corridor and its rooms, and expect every one of them on the deck.

    What the game puts there, not what its file lists: 2F's rival is walked into the corridor by a
    script and is not standing there when you arrive, so he is one of the objects `markers` leaves
    unpinned rather than one lost to a crop."""
    for corridor, floor in SHIP:
        deck = _plan(root, corridor, floor)
        expected = 0
        for label in {p.label for p in deck.placements}:
            const = sources.parse_headers(root)[label][0]
            objects = sources.parse_object_events(root, label, include_battlers=True)
            expected += len([o for o in objects if o["kind"] in ("trainer", "item")])
            expected += len(sources.markers_by_map(root).get(const, []))
        drawn = [p for p in decks.area_markers(root, corridor, floor, 0, 0) if p["cat"] != "exit"]

        assert len(drawn) == expected, f"{corridor}: {expected - len(drawn)} pins lost to a crop"


def test_a_doors_label_drops_the_words_the_deck_has_already_said(root):
    """"S.S. Anne 1F Rooms" six times over one corridor is the ship's name read six times and the
    useful word last. A doorway off the ship shares nothing and keeps its whole name."""
    names = {p["key"]: p["name"] for p in decks.area_markers(root, "SSAnne1F", "1F", 0, 0)
             if p["cat"] == "exit"}

    assert names["E10"] == "Kitchen"
    assert names["E2"] == "Rooms"
    assert names["E1"] == "Vermilion Dock", "off the ship, so nothing to drop"
