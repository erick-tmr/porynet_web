#!/usr/bin/env python3
"""Turn a declarative spec entry into a finished image.

Each generator takes (root, spec) and returns (image, output_name, meta_extra); build.py
saves the PNG and folds meta_extra into the manifest entry. Positions in specs are grid
coordinates (16px overworld cells), never raw pixels.

Spec types:
  map / arrows / npc -> gen_map_scene   : a full map plus manual sprites, auto NPCs, and/or arrows
  dialog / screen    -> gen_screen_scene: a 160x144 GB screen centered on the hero, with a
                                          bottom dialog box (e.g. the hidden-item "found" shot)
  battle             -> gen_battle_scene: the pre-battle face-off frame
(the `arrows` and `npc` types are aliases for `map`; the fields present decide what is drawn.)
"""
import compositor
import follower
import markers
import sources

PLAYER_NAME = "PORYNET"    # our default hero name, all caps like a standard Pokemon name
RIVAL_NAME = "BLUE"        # Yellow's default rival name
RIVAL_CLASSES = {"RIVAL1", "RIVAL2", "RIVAL3"}
HERO_SPRITE = "SPRITE_RED"

# Step off dry land and the game swaps the hero's own sprite, and which one it swaps to is the same
# per-build fact as the follower: LoadSurfingPlayerSpriteGraphics2 (home/overworld.asm) loads
# SurfingPikachuSprite when the Pokemon carrying you is the starter Pikachu and SeelSprite for
# every other surfer. Yellow's hero always has that Pikachu, so Yellow rides it and Red/Blue ride
# the generic blob. `SurfingPikachuSprite` is named by its gfx label because the sheet has no
# SPRITE_* id: nothing in the world is ever built out of it, the engine only loads it over you.
SURF_SPRITE = "SPRITE_SEEL"
PIKACHU_SURF_SPRITE = "SurfingPikachuSprite"

MAP_TYPES = {"map", "arrows", "npc"}
SCREEN_TYPES = {"dialog", "screen"}


def _resolve_sprite(root, entry):
    """Normalize a spec sprite {sprite, grid, dir?/frame?, flip?} to an overlay sprite."""
    file = sources.sprite_file(root, entry["sprite"])
    if "frame" in entry:
        frame, flip = entry["frame"], entry.get("flip", False)
    else:
        frame, flip = compositor.DIR_TO_FRAME.get(entry.get("dir", "DOWN"), (0, False))
    return {"file": file, "frame": frame, "grid": entry["grid"], "flip": flip}


def auto_npcs(root, map_label, battlers=False, show=(), hide=()):
    """Every person object on the map, at its real cell and facing. With `battlers`, also the
    map's trainers and item balls (its leader / gym trainers / ground items). `show` / `hide` move
    an object across its map-load state for a scene set later in the story."""
    out = []
    for obj in sources.parse_object_events(root, map_label, include_battlers=battlers,
                                           show=show, hide=hide):
        frame, flip = compositor.DIR_TO_FRAME.get(obj["direction"], (0, False))
        file = sources.parse_sprite_table(root).get(obj["sprite_const"])
        if file:
            out.append({"file": file, "frame": frame, "grid": list(obj["grid"]), "flip": flip})
    return out


def _dialog_lines(spec_dialog):
    """Resolve a dialog spec to at most two text lines with <PLAYER>/<RIVAL> substituted."""
    if "found_item" in spec_dialog:
        lines = ["<PLAYER> found", f"{spec_dialog['found_item']}!"]
    else:
        lines = spec_dialog["lines"]
    return [line.replace("<PLAYER>", PLAYER_NAME).replace("<RIVAL>", RIVAL_NAME) for line in lines]


def _follower(root, spec, hero_grid, hero_dir, sprites):
    """The overlay sprite for an overworld follower trailing the hero, or None.

    Generic across Gen 1: a follower is drawn only when the game configures one
    (follower.FOLLOWER_SPRITE, e.g. Yellow's SPRITE_PIKACHU), so Red/Blue draw none. A scene's
    `follower` field overrides per shot: false opts out (a pre-follower cutscene, a surf shot beside
    a shore), and a `SPRITE_*` string names a different follower for that scene. A scene that
    hand-places the follower species itself (the sleeping Pikachu in the Jigglypuff trivia) composes
    its own, so we do not trail a second one."""
    override = spec.get("follower", True)
    if override is False:
        return None
    sprite = override if isinstance(override, str) else follower.FOLLOWER_SPRITE
    if sprite is None or any(s.get("sprite") == sprite for s in spec.get("sprites", [])):
        return None
    placed = follower.follower_sprite(root, spec["map"], hero_grid, hero_dir, sprite,
                                      taken=[s["grid"] for s in sprites])
    return _resolve_sprite(root, placed) if placed else None


def gen_map_scene(root, spec):
    """A full map with manual sprites, auto NPCs, and/or directional arrows."""
    image, colors = compositor.render_map(root, spec["map"], spec.get("parent"), spec.get("cut", ()))
    sprites = [_resolve_sprite(root, s) for s in spec.get("sprites", [])]
    if spec.get("auto_npcs"):
        sprites += auto_npcs(root, spec["map"], show=spec.get("show", ()), hide=spec.get("hide", ()))
    hero = next((s for s in spec.get("sprites", []) if s.get("sprite") == HERO_SPRITE), None)
    if hero:
        trailing = _follower(root, spec, hero["grid"], hero.get("dir", "DOWN"), sprites)
        if trailing:
            sprites.append(trailing)
    if sprites:
        image = compositor.overlay_sprites(image, root, sprites, colors,
                                           compositor.grass_cells(root, spec["map"]))
    if spec.get("arrows"):
        image = compositor.overlay_arrows(image, spec["arrows"])
    return image, spec["name"], {}


def afloat(root, map_label, cell):
    """True when a cell is water the hero can only be on by surfing: somewhere they can be, but
    not dry land. Scenes on a map with no header (a composed backdrop) read as dry."""
    headers = sources.parse_headers(root)
    if map_label not in headers:
        return False
    const, tileset = headers[map_label]
    _idx, w_blocks, _h_blocks = sources.parse_map_constants(root)[0][const]
    return not markers.cell_is_land(root, map_label, tileset, w_blocks, tuple(cell))


def hero_sprite(root, spec):
    """The sprite a scene draws its hero with: the surf sprite out on the water, the walking hero
    on land, and whatever `player_sprite` names when a spec overrides both."""
    named = spec.get("player_sprite")
    if named:
        return named
    if afloat(root, spec["map"], spec["player"]):
        return PIKACHU_SURF_SPRITE if follower.FOLLOWER_SPRITE == "SPRITE_PIKACHU" else SURF_SPRITE
    return HERO_SPRITE


def _screen_sprites(root, spec):
    """The cast a screen scene draws: the hero, any hand-placed sprites, and (unless the scene
    composes its own cast) the map's real people and trainers as landmarks.

    Drawing the NPCs is what lets a caption like "one square west of the Bug Catcher" point at
    something: without them the reference tile has no anchor on screen. A hand-composed scene (one
    that places its own `sprites`, e.g. a rival face-off) keeps exactly that cast unless it sets
    `auto_npcs`; every other scene shows its NPCs by default. An NPC on the hero's or a placed
    sprite's cell is dropped so nothing double-draws.

    `show` / `hide` let a scene set later in the story move an object across its map-load state, so
    it comes back (or goes) at its real cell, sprite and facing rather than being retyped as
    `sprites`.

    The hero rides the surf sprite whenever the scene stands them on water, which is read off the
    map rather than declared, so a shot taken from a water tile cannot draw someone walking on the
    sea. `player_sprite` overrides that for the rare shot the rule does not cover."""
    sprites = [_resolve_sprite(root, {"sprite": hero_sprite(root, spec),
                                      "grid": spec["player"],
                                      "dir": spec.get("player_dir", "DOWN")})]
    sprites += [_resolve_sprite(root, s) for s in spec.get("sprites", [])]
    if spec.get("auto_npcs", not spec.get("sprites")):
        taken = {tuple(s["grid"]) for s in sprites}
        sprites += [npc for npc in auto_npcs(root, spec["map"], battlers=True,
                                             show=spec.get("show", ()), hide=spec.get("hide", ()))
                    if tuple(npc["grid"]) not in taken]
    return sprites


# The '!' bubble belongs to whoever the game hangs it on. A trainer who engages on sight flashes
# it over their own head, so it rides on that sprite; a scripted ambush hangs it over the hero
# instead (`wEmotionBubbleSpriteIndex` is 0, the player, in every Jessie & James cutscene), so a
# scene says `player_emote` and it lands on the hero's cell.
def _emotes(spec):
    on_sprites = [{"name": s["emote"], "grid": s["grid"]}
                  for s in spec.get("sprites", []) if s.get("emote")]
    if spec.get("player_emote"):
        return [{"name": spec["player_emote"], "grid": spec["player"]}, *on_sprites]
    return on_sprites


# The two halves of a Gen 1 conversation, which a shot of one has to draw or it shows something
# the game never puts on screen. You can only talk to someone you are facing, and the moment you
# do they turn to face you back: `MakeNPCFacePlayer` in engine/overworld/movement.asm, "Make an
# NPC face the player if the player has spoken to him or her". The one exception in the whole
# game is rubbing the S.S. Anne captain's back (BIT_NO_NPC_FACE_PLAYER), and the one thing you
# may talk across is a counter, which the tilesets name (sources.parse_counter_tiles).
#
# A `found_item` box is never a conversation: pressing A at a tile prints _FoundItemText with
# nobody on the other end, so those are skipped outright. Anything else sets `talking: false` when
# its text box is not a conversation either: an item used on someone (the Poké Flute at the
# sleeping Snorlax) prints its line without anyone being spoken to, so nobody turns.
TALK_EXEMPT = frozenset({"poke_ball", "boulder"})
FACING_BACK = {"UP": "DOWN", "DOWN": "UP", "LEFT": "RIGHT", "RIGHT": "LEFT"}
STEP_OF = {"UP": (0, -1), "DOWN": (0, 1), "LEFT": (-1, 0), "RIGHT": (1, 0)}


def _facing_of(sprite):
    """The direction an overlay sprite looks, back from the (frame, flip) pair it carries."""
    return next((d for d, pair in compositor.DIR_TO_FRAME.items()
                 if pair == (sprite["frame"], sprite["flip"])), None)


def _talked_to(root, spec, hero_dir, cast):
    """The sprite the hero is talking to, or None: whoever stands in the cell they face, reaching
    over one counter tile the way the game does."""
    hx, hy = spec["player"]
    dx, dy = STEP_OF[hero_dir]
    const, tileset = sources.parse_headers(root)[spec["map"]]
    _index, width_blocks, _height = sources.parse_map_constants(root)[0][const]
    counters = sources.counter_tiles(root, tileset)
    tileset_file = sources.tileset_basename(root, tileset)
    for reach in (1, 2):
        cell = (hx + dx * reach, hy + dy * reach)
        found = next((s for s in cast if tuple(s["grid"]) == cell), None)
        if found:
            return found
        tiles = sources.cell_tiles(root, spec["map"], tileset_file, width_blocks, *cell)
        if not counters or not any(tile in counters for tile in tiles):
            return None
    return None


def _check_talking(root, spec, cast):
    """Fail the build on a conversation the game could not have shown.

    Two things go wrong in a hand-written spec, and both draw a frame that cannot happen: the hero
    stood beside the person they are supposedly talking to rather than facing them, and the person
    left looking whichever way the map file parks them rather than turning to the hero."""
    dialog = spec.get("dialog")
    if not dialog or "found_item" in dialog or not spec.get("talking", True):
        return
    hero_dir = spec.get("player_dir", "DOWN")
    people = [s for s in cast
              if s["file"] not in TALK_EXEMPT and tuple(s["grid"]) != tuple(spec["player"])]
    partner = _talked_to(root, spec, hero_dir, people)
    if partner is None:
        placed = {tuple(s["grid"]) for s in spec.get("sprites", [])}
        beside = [cell for cell in ((spec["player"][0] + dx, spec["player"][1] + dy)
                                    for dx, dy in STEP_OF.values()) if cell in placed]
        if beside:
            raise ValueError(
                f"{spec['name']}: the hero faces {hero_dir} with nobody there, but the scene puts "
                f"someone at {beside[0]}. You cannot talk to a sprite you are not facing; turn the "
                f"hero toward them, or set \"talking\": false if this text box is not a conversation.")
        return
    looking = _facing_of(partner)
    if looking != FACING_BACK[hero_dir]:
        raise ValueError(
            f"{spec['name']}: the hero faces {hero_dir} and is talking to {partner['file']} at "
            f"{partner['grid']}, who is drawn facing {looking}. Spoken to, an NPC turns to the "
            f"player (MakeNPCFacePlayer), so it has to be {FACING_BACK[hero_dir]}. Set that "
            f"sprite's dir, or \"talking\": false if this text box is not a conversation.")


def gen_screen_scene(root, spec):
    """A 160x144 GB screen centered on the hero, with optional directional arrows and a
    bottom dialog box.

    `player` is the hero's grid cell (defaults to a marker location for hidden-item shots);
    the hero faces `player_dir` (default DOWN). `sprites` places extra NPCs manually (e.g. the
    rival you meet), auto NPCs are shown at their real cells, `focus` overrides the camera
    center (defaults to the hero), and `cut` fells the cuttable trees the scene is set after."""
    sprites = _screen_sprites(root, spec)
    _check_talking(root, spec, sprites)
    trailing = _follower(root, spec, spec["player"], spec.get("player_dir", "DOWN"), sprites)
    if trailing:
        sprites = [*sprites, trailing]
    emotes = _emotes(spec)
    markers = [{"grid": spec["marker"], "fill": spec.get("marker_color")}] if spec.get("marker") else []
    lines = _dialog_lines(spec["dialog"]) if spec.get("dialog") else None
    image, _ = compositor.render_screen(root, spec["map"], spec.get("focus", spec["player"]),
                                        spec.get("parent"), sprites, spec.get("arrows", []), lines,
                                        emotes=emotes, markers=markers, cut=spec.get("cut", ()))
    return image, spec["name"], {}


def gen_battle_scene(root, spec):
    """The pre-battle face-off frame for a trainer class (rival names are substituted)."""
    opponent = spec["opponent"]
    if opponent in RIVAL_CLASSES:
        name = spec.get("rival_name", RIVAL_NAME)
    else:
        name = spec.get("opponent_name")     # None -> the class name from the game
    kwargs = {k: spec[k] for k in ("enemy_balls", "player_balls", "pic") if k in spec}
    image = compositor.render_battle(root, opponent, opponent_name=name, **kwargs)
    return image, spec["name"], {}


def generate(root, spec):
    """Dispatch a spec to its generator by `type`."""
    kind = spec["type"]
    if kind in MAP_TYPES:
        return gen_map_scene(root, spec)
    if kind in SCREEN_TYPES:
        return gen_screen_scene(root, spec)
    if kind == "battle":
        return gen_battle_scene(root, spec)
    raise ValueError(f"unknown spec type {kind!r}")
