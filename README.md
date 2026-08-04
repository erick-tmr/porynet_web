# PORYNET

An open-source Pokémon **living-dex / collection tracker**. Track every box and
every specimen, walk the **Oak Challenge** alongside the game (each city shows
what's catchable so far and ticks your dex as you play), and let the **save-file
reader** auto-catalog your party and boxes. Your collection lives locally in the
**PoryPC** desktop app — saved on your own computer, works offline, and syncs to
porynet.com (or Google Drive / Dropbox / USB) only when you want it to.

This repository is the **porynet.com** web app: the marketing landing page today,
and the tracker UI as it grows.

> A fan project — not affiliated with Nintendo, Game Freak or The Pokémon
> Company. All trademarks belong to their owners.

## Languages

The site is bilingual, driven by **Rails i18n**:

- English (default) at `/`
- Português (Brasil) at `/pt`

A nav toggle switches between them; copy lives in `config/locales/{en,pt}.yml`.
`test/i18n_parity_test.rb` fails if the two locales ever drift out of sync.

## Tech stack

- **Ruby 3.4.9** / **Rails 8.1** (see `.ruby-version`)
- **PostgreSQL**
- **Propshaft** asset pipeline + **importmap** (no bundler for app JS)
- **Hotwire** (Turbo + Stimulus) — **Node 24** is used only for the JS test suite
- Hand-authored CSS design system (no Tailwind), organized under
  `app/assets/stylesheets/{base,components,pages}`
- Strict Content-Security-Policy (`style-src 'self'`, no inline styles) — all
  styling is class-based

## Getting started

```bash
bin/setup     # install gems + JS deps, prepare the database, and boot the app
bin/dev       # run the app (Rails + jobs) at http://localhost:3000
```

Requires Ruby 3.4.9 (`.ruby-version`), Node 24 (`.node-version`), and a running
PostgreSQL. `bin/setup` handles `bin/rails db:prepare`; to reset later use
`bin/rails db:prepare`.

### Opening the app on your phone (or another machine)

```bash
bin/dev-lan          # prints http://<this-machine>:3000, then boots the app
PORT=4000 bin/dev-lan
```

`bin/dev-lan` is `bin/dev` plus the addressing: it detects this machine's LAN
address, prints the URL to type on the other device (with a QR code when
[`qrencode`](https://fukuchi.org/works/qrencode/) is installed), and points at
the mDNS `http://<hostname>.local:3000` alias for Apple devices and any machine
running Avahi.

Both devices have to be on the same network, and if you run a firewall the port
must be open in it (`sudo ufw allow 3000/tcp` on Linux). Rails accepts raw IPs in
development; to reach the app through a named host instead (an ngrok or
cloudflared tunnel, a Tailscale machine) list it in `DEV_HOSTS` in your `.env`.
To keep the dev server loopback-only, run `BINDING=127.0.0.1 bin/dev`.

## Testing & quality gates

```bash
bin/rails test          # Minitest unit/controller/integration tests
bin/rails test:system   # Capybara + Cuprite (headless Chrome) system tests
npm run test:js         # Vitest (Stimulus controllers, jsdom)
bin/pre-push-check      # run the full CI gate locally before pushing
```

CI (`.github/workflows/ci.yml`) is strict and blocking:

- **100% line + branch coverage** floor (SimpleCov, configured in
  `test/test_helper.rb`) plus **undercover** changed-line coverage vs `main`
- **100% Vitest coverage** for `app/javascript/controllers/*_controller.js`
- Security & lint: RuboCop (omakase), Brakeman, bundler-audit, importmap-audit,
  Semgrep, and Gitleaks

Mark genuinely untestable Ruby with `# :nocov:` and a justifying comment.

## Project layout

- `app/controllers/pages_controller.rb` — the landing (`root "pages#home"`)
- `app/views/pages/*.html.erb` — the landing page, one partial per section
- `app/models/landing_data.rb` — structural demo content (cities, gens, feature
  keys); translatable copy lives in `config/locales/*.yml`
- `app/javascript/controllers/*_controller.js` — Stimulus (oak toggle, city
  selector, language hint)
- `app/assets/stylesheets/` — `base/` tokens & fonts, `components/` primitives,
  `pages/landing.css` section layouts
