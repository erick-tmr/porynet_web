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
import sources

PLAYER_NAME = "PORYNET"    # our default hero name, all caps like a standard Pokemon name
RIVAL_NAME = "BLUE"        # Yellow's default rival name
RIVAL_CLASSES = {"RIVAL1", "RIVAL2", "RIVAL3"}
HERO_SPRITE = "SPRITE_RED"

MAP_TYPES = {"map", "arrows", "npc"}
SCREEN_TYPES = {"dialog", "screen"}


def _resolve_sprite(root, entry):
    """Normalize a spec sprite {sprite, grid, dir?/frame?, flip?} to an overlay sprite."""
    ref = entry["sprite"]
    file = sources.parse_sprite_table(root).get(ref, ref.lower()) if ref.startswith("SPRITE_") else ref
    if "frame" in entry:
        frame, flip = entry["frame"], entry.get("flip", False)
    else:
        frame, flip = compositor.DIR_TO_FRAME.get(entry.get("dir", "DOWN"), (0, False))
    return {"file": file, "frame": frame, "grid": entry["grid"], "flip": flip}


def auto_npcs(root, map_label, battlers=False):
    """Every person object on the map, at its real cell and facing. With `battlers`, also the
    map's trainers and item balls (its leader / gym trainers / ground items)."""
    out = []
    for obj in sources.parse_object_events(root, map_label, include_battlers=battlers):
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
    image, colors = compositor.render_map(root, spec["map"], spec.get("parent"))
    sprites = [_resolve_sprite(root, s) for s in spec.get("sprites", [])]
    if spec.get("auto_npcs"):
        sprites += auto_npcs(root, spec["map"])
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


def _screen_sprites(root, spec):
    """The cast a screen scene draws: the hero, any hand-placed sprites, and (unless the scene
    composes its own cast) the map's real people and trainers as landmarks.

    Drawing the NPCs is what lets a caption like "one square west of the Bug Catcher" point at
    something: without them the reference tile has no anchor on screen. A hand-composed scene (one
    that places its own `sprites`, e.g. a rival face-off) keeps exactly that cast unless it sets
    `auto_npcs`; every other scene shows its NPCs by default. An NPC on the hero's or a placed
    sprite's cell is dropped so nothing double-draws."""
    sprites = [_resolve_sprite(root, {"sprite": HERO_SPRITE, "grid": spec["player"],
                                      "dir": spec.get("player_dir", "DOWN")})]
    sprites += [_resolve_sprite(root, s) for s in spec.get("sprites", [])]
    if spec.get("auto_npcs", not spec.get("sprites")):
        taken = {tuple(s["grid"]) for s in sprites}
        sprites += [npc for npc in auto_npcs(root, spec["map"], battlers=True)
                    if tuple(npc["grid"]) not in taken]
    return sprites


def gen_screen_scene(root, spec):
    """A 160x144 GB screen centered on the hero, with optional directional arrows and a
    bottom dialog box.

    `player` is the hero's grid cell (defaults to a marker location for hidden-item shots);
    the hero faces `player_dir` (default DOWN). `sprites` places extra NPCs manually (e.g. the
    rival you meet), auto NPCs are shown at their real cells, and `focus` overrides the camera
    center (defaults to the hero)."""
    sprites = _screen_sprites(root, spec)
    trailing = _follower(root, spec, spec["player"], spec.get("player_dir", "DOWN"), sprites)
    if trailing:
        sprites = [*sprites, trailing]
    emotes = [{"name": s["emote"], "grid": s["grid"]} for s in spec.get("sprites", []) if s.get("emote")]
    markers = [{"grid": spec["marker"], "fill": spec.get("marker_color")}] if spec.get("marker") else []
    lines = _dialog_lines(spec["dialog"]) if spec.get("dialog") else None
    image, _ = compositor.render_screen(root, spec["map"], spec.get("focus", spec["player"]),
                                        spec.get("parent"), sprites, spec.get("arrows", []), lines,
                                        emotes=emotes, markers=markers)
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
