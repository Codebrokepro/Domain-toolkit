# AGENTS.md — Geo-Domain Toolkit

Instructions for any AI agent (or human) continuing this project.

## What this is

A free, local-first toolkit that automates the domain-trading workflow:
finding domains, qualifying them, tracking the ones you own, finding buyers,
and drafting outreach. It replaces the paid tools reviewed in the source
YouTube playlist, using only free data sources and libraries.

**Primary objective:** implement, feature-for-feature, the free equivalents of
the 12 paid programs in the playlist. The full objective list, what is done,
and the exact next steps live in `ROADMAP.md`. Read it first.

## Non-negotiables

1. **Everything must be free.** No paid APIs, no paid proxies. Free tiers of
   official APIs are allowed only if the user supplies their own key
   (e.g. Google Places, Yelp Fusion, GoDaddy appraisal).
2. **Stay compliant.** Respect robots.txt. Do not build: Google Maps / Yelp
   browser scraping, bulk WhatsApp validation, LinkedIn/social automation,
   free-proxy rotation for evasion, or email "warm-up"/multi-account spam
   tooling. See `ROADMAP.md` "Refused / reframed" for the approved
   alternatives already in place.
3. **No secrets in the repo.** Never hardcode API keys or tokens. Keys are
   stored in the `settings` table via the Settings tab / `/api/settings`.
4. **Keep the existing stack.** Python 3.9+, Flask, SQLite, vanilla JS. Do
   NOT rewrite to FastAPI/React unless the user explicitly asks.

## Run, test, verify

```bash
pip install -r requirements.txt        # Flask + requests only
python3 run.py                         # web dashboard on http://localhost:5000
python3 -m unittest discover -s tests  # full test suite (must stay green)
```

CLI entry point: `python3 -m geodomain.cli <command>` (see `--help`).

Before finishing any task: run the test suite and, if the web layer changed,
restart `run.py` and curl the affected endpoint.

## Architecture

```
run.py                     Flask launcher (PORT env var, default 5000)
start.bat                  Windows one-click launcher (installs deps, opens browser)
geodomain/
  config.py                constants: thresholds, URLs, TLDs, paths
  db.py                    SQLite schema + MIGRATIONS + init_db()/tx()
  net.py                   throttled HTTP get/try_get/try_post (requests)
  cities.py                GeoNames ingest (cities15000)
  niches.py                niche catalog + strength + multipliers
  generator.py             geo sourcing: City + Niche .com
  patterns.py              generator: cvcv, cvcvc, keyword, industry, random, bulk; per-mode prefixes/suffixes; clear
  availability.py          RDAP availability (com/si/generic; reverse check)
  history.py               RDAP age + NS, DoH nameservers, crt.sh, Wayback, drops
  redirect.py              HTTP redirect chain finder (final URL, hops)
  scoring.py               geo 15-criteria score, tier, price band
  brandable.py             .si brandable scoring (availability check on .si only)
  words.py                 free wordlists + word generation for brandables
  godaddy.py               official GoDaddy appraisal adapter
  inventory.py             ownership, expiry alerts, profit/renewal dashboard
  leads.py                 leads CRM, CSV import, provider registry (Google Places / Yelp / Foursquare OS Places / OSM keyless), Overpass presets, Nominatim fallback
  enrich.py                website -> emails, phones, socials (robots-friendly, robots cache, disposable check)
  phone.py                 E.164 normalization + wa.me links
  outreach.py              email templates, follow-up cadence, opt-out, send window/pacing, hygiene, SMTP
  mailcheck.py             SPF/DKIM/DMARC self-check via DNS-over-HTTPS
  social.py                YouTube Data API (free, user key): channel/subscriber stats
  emailtool.py             email validation bridge (HTTP/CLI toolkit) + built-in fallback
  whatsapp.py              opt-in WhatsApp Cloud API adapter (user token, no probing/bulk)
  hunter.py                end-user hunt: OSM/web search -> leads -> enrich
  research.py              web search -> visit result sites -> email/WhatsApp/socials; import to leads
  jobs.py                  background jobs (threaded) for long hunts
  service.py               orchestration + list/stats used by web+cli
  cli.py                   argparse CLI over all modules
  web.py                   Flask app + JSON API
  static/{index.html,style.css,app.js}   dashboard UI
tests/test_core.py         unittest suite
data/                      runtime DB + caches (gitignored)
```

### Data model

One `domains` table holds all domain-like rows, discriminated by `kind`:
`geo` (City+Niche), `brandable` (.si words), `pattern` (generated CVCV/etc).
Inventory fields (registrar, expiry_date, cost, target_price, ...) live on the
same row. `leads` links to `domains` via `domain_id`. Other tables: `cities`,
`outreach`, `optouts`, `settings`, `redirect_checks`. Custom niches are kept in
`data/niches.csv` (runtime, gitignored) and loaded by `niches.load_overrides()`.

Schema changes: add the column to `SCHEMA` **and** to `MIGRATIONS` in
`db.py` so existing databases upgrade on `init_db()`.

## Conventions

- Match the style of neighboring modules; no comments unless non-obvious.
- New module => add CLI subcommand in `cli.py`, JSON routes in `web.py`,
  a UI tab/section in `static/index.html` + `static/app.js`, and unit tests.
- Stages/tiers: geo BUY>=75 / WATCH>=58; brandable/pattern BUY>=72 / WATCH>=55.
- Availability via RDAP: HTTP 200 = registered (taken), 404 = available.
- Keep functions small and single-purpose; reuse `net`, `phone`, scoring helpers.

## Working method

1. Read `ROADMAP.md` and pick the next unchecked task in order.
2. Implement module -> CLI -> API -> UI -> tests.
3. Run tests; restart server; verify the endpoint with curl.
4. Update `ROADMAP.md` status and this file's architecture list if files changed.
