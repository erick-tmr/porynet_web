# Pokemon Yellow asset generator

Renders walkthrough images for the Pokémon Yellow guide straight from the
[`pret/pokeyellow`](https://github.com/pret/pokeyellow) disassembly. Output is our own render of
the game data (not a copy of anyone's rip), the fan-project posture for these assets.

It produces four kinds of image:

- **Area maps**: one plain colored map per walkthrough location (the location header).
- **Annotated maps**: a full map with the hero/NPC sprites and directional pointer arrows, to
  clarify walkthrough directions.
- **NPC maps**: a full map with its real NPCs rendered in place (positions read from the game).
- **Overworld dialog scenes**: a native 160x144 Game Boy screen centered on the hero with the
  standard bottom text box, e.g. the hidden-item "found" shot (`PORYNET found` / `ANTIDOTE!`).
- **Battle scenes**: the pre-battle face-off frame (enemy trainer pic, player back sprite, and
  the `<NAME> wants` / `to fight!` message).

The default hero name is **PORYNET** (all caps, like a standard Pokémon name); `<PLAYER>` and
`<RIVAL>` tokens in dialog text are substituted (`PORYNET` / `BLUE`).

## One-time setup

```sh
git clone --depth 1 https://github.com/pret/pokeyellow ~/Code/pokeyellow
pip install -r tools/maps/requirements.txt   # Pillow (the only runtime dependency)
```

## Run

```sh
python tools/maps/build.py --pokeyellow ~/Code/pokeyellow [--force]
```

This writes:

- `app/assets/images/walkthrough/yellow/{maps,scenes,battles}/<name>.png` — the images
  (gitignored; ship with `deploy/upload-images.sh`).
- `app/models/walkthrough/yellow_maps.json` — the manifest the Rails model loads
  (`Walkthrough::Yellow.map_data` / `map_shot`). Sections: `locations`, `step_shots`
  (step-attached images), `scenes` (standalone dialog/battle/NPC images).
- `tools/maps/REPORT.md` — counts + anything to review.

`--force` re-renders PNGs that already exist (default: skip existing).

## Modules

- `sources.py` — reads structured data out of pokeyellow (maps/tilesets/palettes, overworld
  sprite ids, map object events, the text charmap, trainer classes + pics, hidden-item coords).
  Every parser is cached on the root path.
- `text.py` — renders Game Boy text from the font atlas (`gfx/font/*.png`) + `charmap.asm`,
  including the box-drawing dialog frame.
- `compositor.py` — builds images: `render_map`, `render_battle`, `render_screen` (viewport),
  and the sprite / arrow / dialog overlays.
- `generators.py` — one generator per spec type; returns `(image, name, meta)`.
- `build.py` — the location tables (`_SIMPLE` / `_GYM_CITIES` / `_DUNGEONS`) for area maps, plus
  the spec dispatch, PNG saving, and manifest/report emission.
- `parse_hidden.py` — thin CLI over `sources.markers_by_map` to dump hidden items + coins.

## Adding images

Area maps come from the location tables in `build.py`. Everything else is a declarative entry in
`tools/maps/specs/*.json` (positions are **grid** cells, not pixels):

```jsonc
// map + arrow (step-attached: goes in step_shots[slug][step])
{ "type": "arrows", "slug": "pallet-town", "step": 4, "name": "pallet-town-exit",
  "map": "PalletTown",
  "sprites": [{ "sprite": "SPRITE_RED", "grid": [10, 2], "dir": "UP" }],
  "arrows":  [{ "dir": "up", "grid": [10, 1] }] }

// map + real NPCs (standalone: goes in scenes[name])
{ "type": "npc", "name": "pallet-npcs", "map": "PalletTown", "auto_npcs": true }

// hidden-item "found" dialog screen
{ "type": "dialog", "name": "viridian-forest-antidote", "map": "ViridianForest",
  "player": [16, 42], "auto_npcs": true, "dialog": { "found_item": "ANTIDOTE" } }

// battle face-off (rival names are substituted; others use the class name)
{ "type": "battle", "name": "battle-rival-oaks-lab", "opponent": "RIVAL1", "rival_name": "BLUE" }
```

Sprites take a `SPRITE_*` id (or a raw `gfx/sprites` basename) plus a `grid` cell and a facing
(`dir`: DOWN/UP/LEFT/RIGHT, or an explicit `frame`). `dialog.lines` is an explicit two-line list
(with `<PLAYER>`/`<RIVAL>` substitution); `dialog.found_item` is shorthand for the found-item
template. An entry with `slug` + `step` lands in `step_shots`; otherwise it lands in `scenes`.

A referenced image that isn't uploaded to R2 404s at render (not a test failure), so run
`deploy/upload-images.sh` after generating.

## Tests

`pytest` is a dev-only tool (kept out of `requirements.txt`, which is just the generator's
runtime dep), so install it before running the tests:

```sh
pip install pytest
python -m pytest tools/maps        # needs the pokeyellow checkout (POKEYELLOW=<path> to override)
```

The suite skips (does not fail) if the disassembly isn't present, so it's safe where pokeyellow
isn't cloned.
