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


def _auto_npcs(root, map_label):
    """Every person object on the map, at its real cell and facing."""
    out = []
    for obj in sources.parse_object_events(root, map_label):
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


def gen_map_scene(root, spec):
    """A full map with manual sprites, auto NPCs, and/or directional arrows."""
    image, colors = compositor.render_map(root, spec["map"], spec.get("parent"))
    sprites = [_resolve_sprite(root, s) for s in spec.get("sprites", [])]
    if spec.get("auto_npcs"):
        sprites += _auto_npcs(root, spec["map"])
    if sprites:
        image = compositor.overlay_sprites(image, root, sprites, colors)
    if spec.get("arrows"):
        image = compositor.overlay_arrows(image, spec["arrows"])
    return image, spec["name"], {}


def gen_screen_scene(root, spec):
    """A 160x144 GB screen centered on the hero, with optional directional arrows and a
    bottom dialog box.

    `player` is the hero's grid cell (defaults to a marker location for hidden-item shots);
    the hero faces `player_dir` (default DOWN). auto NPCs are shown at their real cells."""
    player = spec["player"]
    sprites = [_resolve_sprite(root, {"sprite": HERO_SPRITE, "grid": player,
                                      "dir": spec.get("player_dir", "DOWN")})]
    if spec.get("auto_npcs"):
        sprites += _auto_npcs(root, spec["map"])
    lines = _dialog_lines(spec["dialog"]) if spec.get("dialog") else None
    image, _ = compositor.render_screen(root, spec["map"], player, spec.get("parent"),
                                        sprites, spec.get("arrows", []), lines)
    return image, spec["name"], {}


def gen_battle_scene(root, spec):
    """The pre-battle face-off frame for a trainer class (rival names are substituted)."""
    opponent = spec["opponent"]
    if opponent in RIVAL_CLASSES:
        name = spec.get("rival_name", RIVAL_NAME)
    else:
        name = spec.get("opponent_name")     # None -> the class name from the game
    kwargs = {"palette": spec["palette"]} if "palette" in spec else {}
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
