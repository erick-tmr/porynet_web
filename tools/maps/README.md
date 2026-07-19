# Kanto map generator

Renders full colored area maps for the Pokémon Yellow walkthrough straight from the
[`pret/pokeyellow`](https://github.com/pret/pokeyellow) disassembly. Output is our own render of
the game data (not a copy of anyone's map rip), the fan-project posture for map assets. Some step
shots also composite an overworld sprite (e.g. the player standing at the bedroom PC) purely for
illustration.

## One-time setup

```sh
git clone --depth 1 https://github.com/pret/pokeyellow ~/Code/pokeyellow
pip install -r tools/maps/requirements.txt   # Pillow
```

## Run

```sh
python tools/maps/build_manifest.py --pokeyellow ~/Code/pokeyellow [--force]
```

This writes:

- `app/assets/images/walkthrough/yellow/maps/<slug>[-<floor>].png` — colored maps (gitignored; ship with `deploy/upload-images.sh`).
- `app/models/walkthrough/yellow_maps.json` — manifest the Rails model loads (`Walkthrough::Yellow.map_data`).
- `tools/maps/REPORT.md` — counts + anything to review.

`--force` re-renders PNGs that already exist (default: skip existing).

## How it works

- `render_maps.py` — a map is a grid of blocks (4×4 tiles, 32×32 px). Reads `maps/*.blk` +
  `gfx/blocksets/*.bst` + `gfx/tilesets/*.png`; colors each map with its single super-palette
  (`data/sgb/sgb_palettes.asm`) per the game's `SetPal_Overworld` (city / route / cave / cemetery / interior-inherits-town).
  Optionally composites 16×16 overworld sprite frames from `gfx/sprites/*.png` (colored in the map palette).
- `build_manifest.py` — renders each walkthrough location's area map(s) plus any per-step interior
  shots, and emits the manifest. Area maps come from `_SIMPLE` / `_GYM_CITIES` / `_DUNGEONS`;
  step shots (with optional illustrative sprites) come from `_STEP_SHOTS` / `_STEP_SPRITES`.
- `parse_hidden.py` — standalone extractor for the game's hidden-item / Game Corner coin
  coordinates (`data/events/hidden_events.asm` where FUNC == HiddenItems, plus
  `data/events/hidden_coins.asm`). Not part of the map build; kept as the source-of-truth list
  (55 items, 12 coins) for the walkthrough's hand-authored hidden-item entries.

To add or re-scope which pokeyellow maps a location uses, edit `_SIMPLE` / `_GYM_CITIES` /
`_DUNGEONS` in `build_manifest.py`.
