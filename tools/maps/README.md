# Kanto map + hidden-item generator

Renders full colored area maps for the Pokémon Yellow walkthrough straight from the
[`pret/pokeyellow`](https://github.com/pret/pokeyellow) disassembly, and joins the game's
hidden-item / Game Corner coin coordinates as clickable markers. Output is our own render of
the game data (not a copy of anyone's map rip), the fan-project posture for map assets.

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
- `tools/maps/qa/<slug>.png` — marker-overlay previews for eyeballing (gitignored).
- `tools/maps/REPORT.md` — counts + anything to review.

`--force` re-renders PNGs that already exist (default: skip existing).

## How it works

- `render_maps.py` — a map is a grid of blocks (4×4 tiles, 32×32 px). Reads `maps/*.blk` +
  `gfx/blocksets/*.bst` + `gfx/tilesets/*.png`; colors each map with its single super-palette
  (`data/sgb/sgb_palettes.asm`) per the game's `SetPal_Overworld` (city / route / cave / cemetery / interior-inherits-town).
- `parse_hidden.py` — `data/events/hidden_events.asm` (FUNC == HiddenItems) + `data/events/hidden_coins.asm`;
  coords are the 16 px movement grid, cell centre px = `(x*16+8, y*16+8)`.
- `build_manifest.py` — renders each walkthrough location's map(s), normalizes marker px to a
  percent of each image, and emits the manifest. Because we render at exactly `W*32 × H*32` with
  no border, markers land on the render with no calibration.

To add or re-scope which pokeyellow maps a location uses, edit `_SIMPLE` / `_GYM_CITIES` /
`_DUNGEONS` in `build_manifest.py`.
