# PORYNET (porynet_web)

Open-source Pokémon living-dex / collection tracker. Today this is the
porynet.com marketing landing page (single `root "pages#home"` route); the
tracker UI grows from here. Rails 8.1 + PostgreSQL, Propshaft + importmap +
Hotwire, a hand-authored pixel-art CSS design system, bilingual (EN default, PT).

## Commands

- `bin/dev` — Rails server at http://localhost:3000 (Foreman: web + jobs). Postgres must be up first — `docker compose up -d postgres`.
- `bin/setup` — fresh-machine setup: installs gems, starts Postgres via Docker Compose, runs `db:prepare`, then boots the server (`--skip-server` to stop before booting, `--reset` to reset the DB). Needs `cmake` + `pkg-config` for `rugged` (undercover): `brew install cmake` / `sudo apt-get install -y cmake pkg-config`.
- `bin/pre-push-check` — local CI gauntlet; must pass before pushing. `SKIP_TESTS=1` for docs-only pushes.
- `bin/ci` — aggregate runner (`config/ci.rb`): setup → rubocop → bundler-audit → importmap audit → brakeman → `bin/rails test` → `npm ci && npm run test:js`.
- `npm run test:js` — Vitest + jsdom unit tests for Stimulus controllers (`test/javascript/*.test.js`). Node pinned in `.node-version`; run `npm ci` first. `pre-push-check` runs it too.
- `SKIP_COVERAGE_FLOOR=1 HEADLESS=1 bin/rails test:system` — Capybara + Cuprite (headless Chrome) E2E; needs Postgres. `HEADLESS=0` shows the browser. Not in `pre-push-check` (CI's `system-test` job runs it). See **System tests**.

## Stack invariants

- **No Tailwind, no CSS framework, no CDN for CSS/JS/fonts.** The look is a hand-authored design system under `app/assets/stylesheets/{base,components,pages}` (tokens, `@font-face`, `pn-*` components, page layouts), served by **Propshaft**. Fonts are **self-hosted** woff2 in `app/assets/fonts` (Press Start 2P, Pixelify Sans, VT323) — no Google Fonts `<link>` / `preconnect`. Do not add CDN tags or reintroduce Tailwind. (Images are the deliberate exception: served from Cloudflare R2, see the Images bullet below.)
- **Strict Content-Security-Policy** (`config/initializers/content_security_policy.rb`): `default/script/style/font/connect-src 'self'`, `object-src 'none'`. `img-src` is `'self' data:` plus the R2 public host (`config.x.r2_public_host`, added via the initializer). `style-src` has **no nonce** — every style is a CSS class. **No inline `style=` attributes, `<style>` blocks, or `on*=` handlers** (they're blocked). `script-src` carries a per-request nonce solely for the importmap JSON block. Locale strings that need markup use `_html` keys that reference existing CSS classes, never inline styles.
- **Hotwire is live** (unlike a storefront where it may be inert). Turbo + Stimulus boot; interactive widgets are Stimulus controllers in `app/javascript/controllers/*_controller.js` (oak toggle, city selector, language hint), auto-registered via `eagerLoadControllersFrom` + `pin_all_from`. A new widget is a new controller **with a Vitest spec at 100% coverage** (see **CI gates**). Read config from `data-*` values; keep motion in CSS and honor `prefers-reduced-motion`.
- **i18n.** English is default at `/`, Português at `/pt`, via `scope "(:locale)"` + `switch_locale` / `default_url_options` in `ApplicationController`; `<html lang>` is dynamic. All UI copy lives in `config/locales/{en,pt}.yml` under `pages.home.*` — never hardcode strings in views. Non-translatable structure (city / region / Pokémon names, counts, feature keys) lives in `app/models/landing_data.rb`. `test/i18n_parity_test.rb` fails if the en/pt key sets drift, and `raise_on_missing_translations` is on in dev/test so a missing key fails loudly.
- **Images are served from Cloudflare R2**, not Propshaft. Reference them with the `r2_image_tag` / `r2_asset_url` helpers (`app/helpers/application_helper.rb`), which prefix `config.x.r2_public_host`; the object key is the path relative to `app/assets/images/` (e.g. `r2_image_tag "pokemon/yellow/025.png"`). The source PNGs under `app/assets/images/` are **gitignored** (kept locally for uploads, re-derivable from `vendor/pokeapi-sprites/`) and pushed to the bucket with `deploy/upload-images.sh` (`Assets::R2Uploader`). The upload is **incremental**: a gitignored fingerprint cache (`app/assets/images/.r2-upload-cache.json`) records each image's content digest, so a re-run sends only the images whose bytes changed (regenerating an unchanged, deterministic map is a no-op). Pass `deploy/upload-images.sh --force` to re-send everything (fresh/prod bucket), and `Assets::R2Uploader#prime_cache` to mark the current files as already uploaded without sending (seed the cache when the bucket is known to match). Per-env host: dev + test use the dev bucket `porynet-dev` (`pub-...r2.dev`); prod injects `R2_PUBLIC_HOST` (not wired to a prod bucket yet, so set it and upload before the next prod deploy). R2 write keys live in the default Rails credentials (`bin/rails credentials:edit`, keys `r2.access_key_id` / `r2.secret_access_key`), which dev reads automatically; prod will use env-scoped `config/credentials/production.yml.enc`. Serving public objects needs no keys. Favicons in `public/` (`icon.png`, `icon.svg`) stay same-origin.
- **Sprite sources** (where the source PNGs come from before they go to R2):
  - **Pokémon, item, badge, and type sprites**: the cloned [PokeAPI/sprites](https://github.com/PokeAPI/sprites) repo at `vendor/pokeapi-sprites/sprites/{pokemon,items,badges,types}/`. Item sprites live in [`sprites/items/`](https://github.com/PokeAPI/sprites/tree/master/sprites/items) (~900 kebab-case PNGs: `nugget.png`, `moon-stone.png`, `hm01.png`, `card-key.png`, `poke-flute.png`, ...). This is the source for walkthrough item cards (`app/assets/images/walkthrough/items/*.png`, keyed by `Walkthrough::Yellow.item_sprite`).
  - **Trainer sprites**: [Pokémon Showdown](https://play.pokemonshowdown.com/sprites/trainers/) (browse with `?view=dir`).
  - Flow to add a sprite: copy the source PNG into the matching `app/assets/images/...` path (the object key), then upload with `deploy/upload-images.sh`. A referenced image that isn't in the bucket 404s at render (not a test failure), so upload before wiring a new sprite into a view.

## Conventions

- **No code comments unless asked.** Write self-documenting code (clear names, small methods/partials); do not add explanatory comments. Add one only when the user explicitly requests it. Functional pragmas are not "comments" and must stay: `# :nocov:`, `# rubocop:…`, `# nosemgrep:<rule-id>` (with a one-line reason), reek justifications in `.reek.yml`, Ruby magic comments, and the JS analogue for un-testable bootstrap (`/* v8 ignore */` / a `vitest.config.js` exclusion).
- Greenfield repo: delete unused code rather than commenting it out, renaming to `_var`, or adding backwards-compat shims.
- Pin every new gem with a pessimistic constraint (`gem "foo", "~> 1.2"`), floored at the installed minor.
- Never bypass hooks (`--no-verify`, disabling signing) — fix the underlying cause if a hook fails.
- `bundler-audit` + `brakeman` block on findings. Fix the cause; don't add ignores without flagging it in the PR. Keep **reek at zero on changed files** — fix the smell or silence it in `.reek.yml` with a justifying comment.
- Customer-facing strings are localized (`t(...)`, EN + PT), never hardcoded. The brand wordmark is **PORYNET**; the desktop app is **PoryPC** (one word).
- New env vars: document in `.env.example` (committed), set the value in `.env` (gitignored).

## System tests

- **Capybara + Cuprite** (headless Chrome over CDP — no Selenium/WebDriver), Minitest. Foundation in `test/application_system_test_case.rb`; specs in `test/system/*.rb`.
- Run **serial** (`parallelize(workers: 1)`); **never `sleep`** — rely on Capybara's auto-waiting matchers (`assert_selector`, `assert_current_path`); `default_max_wait_time = 2`, animations disabled. Prefer stable `data-*` / class hooks over localized copy.
- The CI `system-test` job runs with `SKIP_COVERAGE_FLOOR=1`: system paths aren't held to the whole-app SimpleCov 100% floor (that floor is the unit/integration run's contract). Run it the same way locally.

## Walkthrough assets (Pokémon Yellow)

Walkthrough screenshots are **generated**, not captured: `python tools/maps/build.py --pokeyellow ~/Code/pokeyellow [--force] [--palette gbc|sgb|dmg]` renders every image straight from the [`pret/pokeyellow`](https://github.com/pret/pokeyellow) disassembly (clone it there first). It is deterministic: the same disassembly plus the same specs yields byte-identical PNGs. It writes the PNGs under `app/assets/images/walkthrough/yellow/{maps,scenes,battles}/` (gitignored, served from R2), the manifest `app/models/walkthrough/yellow_maps.json`, and `tools/maps/REPORT.md`. Full spec schema and the "where each fact lives in pokeyellow" cheatsheet are in `tools/maps/README.md`.

- **Scenes are declarative JSON** in `tools/maps/specs/*.json` (area maps come from the location tables in `build.py`). Positions are **grid** cells (16px tiles), which are the game's own object coordinates; map sizes in `constants/map_constants.asm` are in blocks (double for grid cells).
- **Reading the game** (all under `~/Code/pokeyellow`): NPC / item / trainer positions, facings, and the edge-fill border block are in `data/maps/objects/<Map>.asm`; hidden items in `data/events/hidden_events.asm`; the generic pickup line is `_FoundItemText` (`<PLAYER> found` / `<ITEM>!`); a trainer's map object gives `OPP_<CLASS>, <party#>`, matched to the model team via `data/trainers/parties.asm`; the spotted `!` bubble is `gfx/emotes/shock.png` (`EXCLAMATION_BUBBLE`).
- **Rendering** pins the hero near center and fills beyond the map edge with the map's border block (grass or water outdoors, solid black inside buildings). Useful spec fields: `focus` (camera center, to hold the framing while the hero moves), `emote` on a sprite (the `!` bubble), `marker` (a baked neon-magenta locator dot for a hidden item; CSS adds only the pulsing glow, positioned to the dot's measured `%`), and `parent` (an interior inherits that town's palette).
- **Workflow**: find the data in pokeyellow, add or edit a spec, `build.py --force`, eyeball the PNG, then wire `app/models/walkthrough/yellow.rb` (`map_shot(slug, step, label)` for a step shot, `scene_shot(name, label)` for a trainer `where:` or other standalone scene, `hidden(...)` for a hidden item), run `deploy/upload-images.sh` (a referenced image not yet in R2 404s at render, it is not a test failure), then `bin/pre-push-check`. The renderer has its own pytest suite: `python -m pytest tools/maps`.
- **Regression tests are mandatory for any generator change (never skip this).** The markers baked into `yellow_maps.json` are pinned per map by `tools/maps/tests/test_manifest.py`: a **golden** test rebuilds every map from the game data and asserts it equals the committed manifest, and a **strip-invariant** test asserts every map-connection exit sits inside the strip the header actually shares (the offset in `data/maps/headers/<Map>.asm`), not just any open tile on the edge. So whenever you touch the marker/exit logic (`markers.py`, `sources.py`, specs) or fix one map's placement:
  1. Run `POKEYELLOW=~/Code/pokeyellow python -m pytest tools/maps` first, then regenerate with `build.py` (the golden test fails until the committed manifest is regenerated).
  2. **Review the full `git diff` of `yellow_maps.json`** and confirm only the maps you intended to change moved. Fixing one map must not silently shift others; the golden test surfaces every map that changed so you can catch collateral damage before it ships.
  3. Add or update a case in `test_manifest.py` (or `test_markers.py`) for the specific placement you fixed, so the corrected position is locked against future drift.
  A referenced image not yet in R2 404s at render but is not a test failure; a shifted marker with no test *is* the failure this suite exists to prevent.
- **Scene / sprite rendering is baked into the PNGs, not the manifest, so it needs the same discipline through a different door.** Changing what a scene draws (`generators.py`, `compositor.py`, e.g. which NPCs a hidden-item shot shows) does **not** move the manifest; it changes pixels, so: cover the behaviour with a `tools/maps/tests/test_generators.py` test that asserts the *decision* (e.g. `_screen_sprites` includes the trainer a caption points at, a hand-composed scene keeps only its own cast), then regenerate with `build.py --force` (plain `build.py` skips PNGs that already exist) and **re-upload** with `deploy/upload-images.sh` so the app stops serving the stale image from R2. Screen scenes draw their map's real people (trainers included) as landmarks by default; a scene that places its own `sprites` keeps exactly that cast unless it sets `auto_npcs`.

## Git workflow

- Branch from `main`: `git fetch origin && git switch -c <type>/<short-desc> origin/main` (`feat` / `fix` / `chore` / `docs`). Don't branch off another feature branch — a not-yet-merged base makes noisy PRs.
- `bin/pre-push-check` must pass before pushing. Never `--force` to `main`.
- Open PRs with `gh pr create`; merge from GitHub. **After pushing, verify CI with `gh pr checks <N>`** — the local gauntlet doesn't run `Semgrep (new findings)`, `Dependency review`, or `system-test`, so a green pre-push can still produce a red PR. Inspect failures with `gh run view <run-id> --log-failed`; the sticky `ci-quality` comment carries the coverage/reek/semgrep summary.

## CI gates

One workflow (`.github/workflows/ci.yml`). **Blocking**: RuboCop (omakase), Brakeman, bundler-audit, importmap audit, tests + system-tests, **SimpleCov 100% line + branch floor** (configured in `test/test_helper.rb`), **undercover** (changed-line coverage vs `main`), **Vitest** JS unit tests, **Semgrep `(new findings)`**, **Gitleaks**, **Dependency review** (moderate+ CVEs). **Advisory**: reek, reported in the sticky `ci-quality` PR comment. Brakeman + Semgrep findings also surface under **Security ▸ Code scanning**. The SimpleCov floor + undercover together enforce both "every changed line is tested" and "no coverage regressions." Mark genuinely un-testable Ruby with `# :nocov:` + a reason. JS coverage is **separate** (Vitest, its own 100% threshold in `vitest.config.js`, scoped to `app/javascript/controllers/*_controller.js`).

## Gotchas

- Rails checks pending migrations on every dev request → Postgres must be up (`docker compose up -d postgres`) before `bin/dev`.
- Postgres is bound to `127.0.0.1` in `compose.yaml` (so a LAN-shared `bin/dev` doesn't expose the DB). Do not switch to `0.0.0.0`.
- **Never use em-dashes (the `—` character) anywhere.** Not in authored prose (commit messages, PR bodies, chat replies) and not in UI or locale copy. They read as AI-generated. Use commas, periods, parentheses, or colons instead. En-dashes in numeric ranges (e.g. `2–5` levels) are fine; this rule is about the `—` em-dash only.
- Cuprite system tests need Chrome / Chromium installed locally.
- `.env.example` is the only `.env*` that ships (`.gitignore` carves it out).
