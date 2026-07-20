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
python tools/maps/build.py --pokeyellow ~/Code/pokeyellow [--force] [--palette gbc|sgb|dmg]
```

`--palette` picks which hardware's colors to render everything in (default **gbc**):

- `gbc` — Game Boy Color, the game's `CGBBasePalettes` (saturated; e.g. Oak's Lab purple).
- `sgb` — Super Game Boy, the paler `SuperPalettes`.
- `dmg` — the original Game Boy's four greens (monochrome). Sprites, dialog scenes and battle
  scenes all follow the chosen mode.

This writes:

- `app/assets/images/walkthrough/yellow/{maps,scenes,battles}/<name>.png` — the images
  (gitignored; ship with `deploy/upload-images.sh`).
- `app/models/walkthrough/yellow_maps.json` — the manifest the Rails model loads
  (`Walkthrough::Yellow.map_data` / `map_shot`). Sections: `locations`, `step_shots`
  (step-attached images), `scenes` (standalone dialog/battle/NPC images). Each `locations`
  entry carries its `markers`: the trainers, item balls, hidden items and exits the page
  overlays, positioned as percentages of the PNG so the layer survives any render width.
- `tools/maps/REPORT.md` — counts + anything to review.

`--force` re-renders PNGs that already exist (default: skip existing).

`Walkthrough::Yellow.manifest` is memoized, and Rails only reloads it when the Ruby file
changes. After a rebuild that touches only the JSON, restart `bin/dev`.

The area-map PNGs keep their object keys across rebuilds, so a forgotten
`deploy/upload-images.sh` does not 404 the way a brand-new sprite would. It silently serves the
previous render instead, with nothing in the logs. Upload every time the images change.

## Modules

- `sources.py` — reads structured data out of pokeyellow (maps/tilesets/palettes, overworld
  sprite ids, map object events, the text charmap, trainer classes + pics, hidden-item coords).
  Every parser is cached on the root path.
- `text.py` — renders Game Boy text from the font atlas (`gfx/font/*.png`) + `charmap.asm`,
  including the box-drawing dialog frame.
- `compositor.py` — builds images: `render_map`, `render_battle`, `render_screen` (viewport),
  and the sprite / arrow / dialog overlays.
- `generators.py` — one generator per spec type; returns `(image, name, meta)`.
- `markers.py` — the clickable overlay data for an area map: trainers, item balls, hidden items
  and exits, as percentages of the rendered PNG.
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

// hidden-item "found" dialog screen, with the baked pink locator dot on the item's tile
{ "type": "dialog", "name": "viridian-forest-antidote", "map": "ViridianForest",
  "player": [15, 42], "player_dir": "RIGHT", "auto_npcs": true,
  "marker": [16, 42], "dialog": { "found_item": "ANTIDOTE" } }

// trainer spotting the hero (the "!" bubble); the hero stands in the trainer's line of sight
{ "type": "screen", "name": "vf-bug-catcher-1", "map": "ViridianForest",
  "player": [27, 33], "player_dir": "RIGHT", "focus": [28, 33],
  "sprites": [{ "sprite": "SPRITE_YOUNGSTER", "grid": [30, 33], "dir": "LEFT", "emote": "shock" }] }

// battle face-off (rival names are substituted; others use the class name)
{ "type": "battle", "name": "battle-rival-oaks-lab", "opponent": "RIVAL1", "rival_name": "BLUE" }
```

`screen` / `dialog` fields:

- `player` [gx,gy] + `player_dir` (DOWN/UP/LEFT/RIGHT): the hero sprite and facing.
- `focus` [gx,gy]: camera center override (defaults to `player`). Use it to hold the framing
  while moving the hero, e.g. lower the hero but keep a building's black ceiling in frame.
- `sprites`: each takes a `SPRITE_*` id (or a raw `gfx/sprites` basename), a `grid` cell, a
  facing (`dir`, or an explicit `frame`), optional `flip`, and optional `emote` (a
  `gfx/emotes/*` name, e.g. `"shock"` for the spotted `!`) drawn one cell above it.
- `auto_npcs`: also draw every real map object at its cell/facing (from the object events).
- `arrows`: `[{ dir: up|down|left|right, grid:[gx,gy] }]` amber pointer overlays.
- `dialog`: `{ found_item: "ITEM" }` for the `<PLAYER> found / ITEM!` box, or `{ lines: [a,b] }`
  for two explicit lines (`<PLAYER>`/`<RIVAL>` substituted).
- `marker` [gx,gy]: bakes a flat neon-magenta dot (`#FF3DAE`) on that cell for a hidden item;
  the page adds only the pulsing glow in CSS, positioned to the dot's `%` (measure the dot
  centroid in the PNG and set `.pn-wt-pin--<pin>`).
- `parent`: a `*_CITY` / town const so an interior inherits that map's palette (see below).

An entry with `slug` + `step` lands in `step_shots[slug][step]` (wire it with `map_shot`);
otherwise it lands in `scenes[name]` (wire it with `scene_shot`, or `hidden` for hidden items).
The camera pins the hero near center and fills past the map edge with the map's **border block**
(grass/water outdoors, solid black inside buildings). A referenced image that isn't uploaded to
R2 404s at render (not a test failure), so run `deploy/upload-images.sh` after generating.

## Finding the data in pokeyellow

Every position, facing and string is read straight from the disassembly. Grid cells in the specs
are the game's own object/warp coordinates (16px tiles); `constants/map_constants.asm` gives map
size in **blocks** (x2 for grid cells).

- **NPCs / items / trainers on a map**: `data/maps/objects/<Map>.asm` (`object_event x, y, SPRITE_*,
  movement, facing, TEXT_*[, item | OPP_*, party]`). The `db $X ; border block` line is the
  edge-fill block. Warps and connections: same file plus `data/maps/headers/<Map>.asm`.
- **Hidden items**: `data/events/hidden_events.asm` (`hidden_events_for <MAP>` -> coord + item).
- **Item / sign / NPC text**: `text/<Map>.asm`; the generic pickup line is `_FoundItemText`
  (`<PLAYER> found / <ITEM>!`) in `data/text/`.
- **Matching a model trainer to its map object**: the object gives `OPP_<CLASS>, <party#>`; look up
  that party in `data/trainers/parties.asm` and match it to the team in `yellow.rb`. Pass the pair
  to `tr(..., opp: ["BUG_CATCHER", 1])` and the trainer card picks up the same key letter its pin
  carries on the map.
- **Conditional assembly**: `RedsHouse2F.asm` guards four playtest warps behind `IF DEF(_DEBUG)`.
  They are not in the retail ROM, so `sources._map_object_lines` strips them before any parse.
- **The spotted `!` bubble**: `EXCLAMATION_BUBBLE` is index 0 of `EmotionBubbles`
  (`engine/overworld/emotion_bubbles.asm`) = `gfx/emotes/shock.png`.
- **Palette**: `SetPal_Overworld` (`engine/gfx/palettes.asm`). A building inherits the palette of
  the town/route it sits in (`wLastMap`); pass that town const as `parent` for interiors that look
  wrong with the default (caverns/cemeteries are handled automatically).

## Tests

`pytest` is a dev-only tool (kept out of `requirements.txt`, which is just the generator's
runtime dep), so install it before running the tests:

```sh
pip install pytest
python -m pytest tools/maps        # needs the pokeyellow checkout (POKEYELLOW=<path> to override)
```

The suite skips (does not fail) if the disassembly isn't present, so it's safe where pokeyellow
isn't cloned.
