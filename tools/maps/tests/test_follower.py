import follower
import markers
import sources

PIKACHU = "SPRITE_PIKACHU"


def _is_land(root, map_label, cell):
    const, tileset = sources.parse_headers(root)[map_label]
    width_blocks = sources.parse_map_constants(root)[0][const][1]
    return markers.cell_is_land(root, map_label, tileset, width_blocks, cell)


def test_follower_stands_directly_behind_and_faces_the_hero(root):
    # Pallet Town's north exit: the hero at [10, 3] faces up, so the follower trails on the tile
    # the hero just left ([10, 4], one cell down) and looks back up at them.
    spr = follower.follower_sprite(root, "PalletTown", [10, 3], "UP", PIKACHU, taken=[[10, 3]])
    assert spr == {"sprite": PIKACHU, "grid": [10, 4], "dir": "UP"}


def test_follower_draws_whatever_sprite_it_is_handed(root):
    # The engine is game-agnostic: it trails the sprite it is given, not a hardcoded Pikachu.
    spr = follower.follower_sprite(root, "PalletTown", [10, 3], "UP", "SPRITE_OAK", taken=[[10, 3]])
    assert spr["sprite"] == "SPRITE_OAK"


def test_follower_is_always_adjacent_and_faces_the_hero(root):
    # Whatever cell it settles on, the follower is one step from the hero and looks straight at them.
    hero = [13, 24]
    for facing in ("UP", "DOWN", "LEFT", "RIGHT"):
        spr = follower.follower_sprite(root, "Route1", hero, facing, PIKACHU, taken=[hero])
        assert spr is not None
        gx, gy = spr["grid"]
        offset = (gx - hero[0], gy - hero[1])
        assert abs(offset[0]) + abs(offset[1]) == 1, f"{facing}: adjacent to the hero"
        assert spr["dir"] == follower._FACE_TOWARD[offset], f"{facing}: faces back at the hero"


def test_follower_never_straddles_a_hedge(root):
    """Regression for the Route 3 Youngster card: the follower behind the hero at [14, 6] used to
    land on [14, 7], a cell open above but with its feet on the hedge. It now steps to a cell the
    game would let it stand on (lower-left walkable)."""
    spr = follower.follower_sprite(root, "Route3", [14, 6], "UP", PIKACHU, taken=[[14, 6]])
    assert spr["grid"] != [14, 7]
    const, tileset = sources.parse_headers(root)["Route3"]
    width = sources.parse_map_constants(root)[0][const][1]
    assert markers.cell_is_standable(root, "Route3", tileset, width, tuple(spr["grid"]))


def test_follower_steps_aside_when_the_tile_behind_is_solid(root):
    # Route 5's underground-path house: the hero at [17, 28] faces up with its back to the house
    # wall ([17, 29] is solid), so the follower cannot trail directly behind and takes the open
    # tile beside the hero instead, still facing them.
    assert not _is_land(root, "Route5", (17, 29)), "the tile behind the hero is solid"
    spr = follower.follower_sprite(root, "Route5", [17, 28], "UP", PIKACHU, taken=[[17, 28]])
    assert spr["grid"] != [17, 29]
    gx, gy = spr["grid"]
    offset = (gx - 17, gy - 28)
    assert abs(offset[0]) + abs(offset[1]) == 1 and spr["dir"] == follower._FACE_TOWARD[offset]


def test_follower_avoids_cells_another_sprite_already_holds(root):
    # With the tile behind the hero taken (e.g. by an NPC), the follower picks a different free cell.
    behind = [10, 4]
    spr = follower.follower_sprite(root, "PalletTown", [10, 3], "UP", PIKACHU, taken=[[10, 3], behind])
    assert spr is not None and spr["grid"] != behind


def test_no_follower_when_the_hero_is_ringed_by_water(root):
    # A hero out on the Seafoam water ([6, 4], every neighbour open sea) is surfing, so the land
    # follower is not drawn.
    assert follower.follower_sprite(root, "SeafoamIslandsB4F", [6, 4], "UP", PIKACHU, taken=[[6, 4]]) is None


def test_no_follower_on_a_map_without_a_header(root):
    assert follower.follower_sprite(root, "NoSuchMap", [1, 1], "DOWN", PIKACHU) is None
