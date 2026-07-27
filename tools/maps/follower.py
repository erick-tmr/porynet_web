#!/usr/bin/env python3
"""Place an overworld follower that trails the hero, one cell behind and facing back at them.

This is game-agnostic: it draws whatever sprite it is handed, wherever the hero can drag it. The
one Gen 1 game that uses it is Yellow, where the starter Pikachu shadows the hero everywhere in
the overworld; Red and Blue have no follower, so nothing calls in with a sprite and the hero walks
alone. Which sprite (if any) trails the hero is a per-build choice: `FOLLOWER_SPRITE` holds the
default the generators reach for, set by the game's build (Yellow -> SPRITE_PIKACHU), and a scene
can name its own or opt out entirely.

The placement mirrors Yellow's follower engine (CalculatePikachuPlacementCoords state 2 +
ComputePikachuFacingDirection in engine/pikachu/pikachu_follow.asm): right after a step the
follower settles on the tile the hero just walked off (opposite their facing) and looks back at
them, which reads as "following behind". The same collision that stops the hero stops the
follower, so when the tile behind is off the map or solid we fall back to the nearest walkable
dry-land neighbour. A follower only ever stands on dry land, never water, so a hero out surfing
(ringed by sea) gets none, which is right for a land follower.
"""
import markers
import sources

# The sprite that trails the hero by default, or None for a game with no follower (Gen 1 R/B).
# The build sets it (Yellow: "SPRITE_PIKACHU"); a spec can still override or opt out per scene.
FOLLOWER_SPRITE = None

# hero facing -> the neighbour cells to try, behind first (opposite the way the hero looks), then
# the two sides, then the tile the hero faces. The first walkable land cell wins, so the follower
# trails the hero whenever it can and only steps aside when a wall is in the way.
_TRY_ORDER = {
    "DOWN":  [(0, -1), (-1, 0), (1, 0), (0, 1)],
    "UP":    [(0, 1), (1, 0), (-1, 0), (0, -1)],
    "LEFT":  [(1, 0), (0, -1), (0, 1), (-1, 0)],
    "RIGHT": [(-1, 0), (0, 1), (0, -1), (1, 0)],
}

# a neighbour offset -> the direction the follower looks to face the hero from it
_FACE_TOWARD = {(0, -1): "DOWN", (0, 1): "UP", (-1, 0): "RIGHT", (1, 0): "LEFT"}


def follower_sprite(root_str, map_label, hero_grid, hero_dir, sprite, taken=()):
    """Return the follower sprite {sprite, grid, dir} for a hero at `hero_grid` facing `hero_dir`,
    or None when no follower fits.

    `sprite` is the overworld sprite id to trail (e.g. "SPRITE_PIKACHU"). The cell behind the hero
    is preferred, then the nearest walkable dry-land neighbour not already taken by another sprite;
    the follower faces back toward the hero from wherever it lands. Returns None when the map has
    no header or no neighbour is dry land it can stand on (a hero ringed by water is surfing)."""
    headers = sources.parse_headers(root_str)
    if map_label not in headers:
        return None
    const, tileset = headers[map_label]
    _idx, w_blocks, h_blocks = sources.parse_map_constants(root_str)[0][const]
    w_cells, h_cells = w_blocks * 2, h_blocks * 2
    hx, hy = hero_grid
    blocked = {tuple(t) for t in taken}

    for dx, dy in _TRY_ORDER.get(hero_dir, _TRY_ORDER["DOWN"]):
        cell = (hx + dx, hy + dy)
        if cell in blocked or not (0 <= cell[0] < w_cells and 0 <= cell[1] < h_cells):
            continue
        if markers.cell_is_standable(root_str, map_label, tileset, w_blocks, cell):
            return {"sprite": sprite, "grid": [cell[0], cell[1]], "dir": _FACE_TOWARD[(dx, dy)]}
    return None
