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

- **No Tailwind, no CSS framework, no CDN.** The look is a hand-authored design system under `app/assets/stylesheets/{base,components,pages}` (tokens, `@font-face`, `pn-*` components, page layouts), served by **Propshaft**. Fonts are **self-hosted** woff2 in `app/assets/fonts` (Press Start 2P, Pixelify Sans, VT323) — no Google Fonts `<link>` / `preconnect`. Do not add CDN tags or reintroduce Tailwind.
- **Strict Content-Security-Policy** (`config/initializers/content_security_policy.rb`): `default/script/style/font/img/connect-src 'self'`, `object-src 'none'`. `style-src` has **no nonce** — every style is a CSS class. **No inline `style=` attributes, `<style>` blocks, or `on*=` handlers** (they're blocked). `script-src` carries a per-request nonce solely for the importmap JSON block. Locale strings that need markup use `_html` keys that reference existing CSS classes, never inline styles.
- **Hotwire is live** (unlike a storefront where it may be inert). Turbo + Stimulus boot; interactive widgets are Stimulus controllers in `app/javascript/controllers/*_controller.js` (oak toggle, city selector, language hint), auto-registered via `eagerLoadControllersFrom` + `pin_all_from`. A new widget is a new controller **with a Vitest spec at 100% coverage** (see **CI gates**). Read config from `data-*` values; keep motion in CSS and honor `prefers-reduced-motion`.
- **i18n.** English is default at `/`, Português at `/pt`, via `scope "(:locale)"` + `switch_locale` / `default_url_options` in `ApplicationController`; `<html lang>` is dynamic. All UI copy lives in `config/locales/{en,pt}.yml` under `pages.home.*` — never hardcode strings in views. Non-translatable structure (city / region / Pokémon names, counts, feature keys) lives in `app/models/landing_data.rb`. `test/i18n_parity_test.rb` fails if the en/pt key sets drift, and `raise_on_missing_translations` is on in dev/test so a missing key fails loudly.
- Images live in `app/assets/images/` (Propshaft, `image_tag`). No external image hosts.

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
