# ROADMAP — Free equivalents of the 12 paid domain-trading tools

Goal: reproduce, for free, every tool in the source playlist ("مراجعة برامجنا",
12 videos by MM Domains). One app, many modules. Status legend:
`[x]` done, `[~]` partial, `[ ]` todo, `[separate]` belongs in another project,
`[refused]` intentionally not built (see bottom).

How to continue: take the first `[ ]` task in order, implement it, add tests,
verify, then update this file.

---

## Objective map

| # | Playlist tool | Where it lives | Status |
|---|---------------|----------------|--------|
| 1 | Domain Pro | `inventory.py` (ownership, expiry, profit) | [x] |
| 2 | MM Outbound Pro (URLs -> contacts) | `enrich.py` + `leads.py` | [x] |
| 3 | DNS History / Nameserver Checker | `history.py` | [x] |
| 4 | Redirect Finder | `redirect.py` | [x] |
| 5 | Maps Scraper (compliant) + WhatsApp Verifier | `leads.py` (Places/Yelp/OSM); WhatsApp = manual | [x] |
| 6 | Email Validator Pro | separate project | [separate] |
| 7 | Email Finder | separate project | [separate] |
| 8 | Domain Sales Manager | merged into `inventory.py` + `leads.py` | [x] |
| 9 | Domain Monitor | merged into `inventory.py` | [x] |
| 10 | Domain Master Pro | `generator.py` + `patterns.py` + `availability.py` | [x] |
| 11 | End User Hunter | new `hunter.py` | [x] |
| 12 | Lead Extractor Pro | `enrich.py` | [x] |

Notes: 6+7 are generic email utilities -> a separate "Email Toolkit" project
(this app calls it, does not contain it). 1+8+9 are one CRM/inventory core.

---

## Done

- [x] **Geo sourcing** (`generator.py`): GeoNames cities x niche catalog ->
  `CityNiche.com`; RDAP availability; 15-criteria score, tier, price band.
  Custom niches: `niches add` persists new niches to `data/niches.csv`, and
  `generate --niche X --all-cities` (or the Dashboard "Add a new niche" panel)
  creates `City+X.com` for every city.
- [x] **Brandable .si finder** (`brandable.py`, `words.py`): free wordlists,
  `.si` RDAP, scoring (length, dictionary, pronounceability, AI theme).
  Dashboard results are paginated (limit/offset + filtered total count), with
  a regression test covering more than 200 stored candidates. Repeated runs
  skip labels already stored for the TLD, so each run adds unseen candidates.
- [x] **Domain generator** (`patterns.py`): cvcv, cvcvc, 4-letter non-cvcv,
  keyword, industry, random, bulk list; prefixes/suffixes applied to every
  mode; clear generated set; RDAP check + scoring; `kind='pattern'`.
- [x] **Inventory / Sales / Monitor** (`inventory.py`): registrar, purchase &
  expiry dates, cost, target/min/renewal price, listing, status; expiry alerts
  (30/60/90d + expired); profit pipeline; realized profit; registrar breakdown;
  annual renewal cost. GoDaddy appraisal adapter (`godaddy.py`).
- [x] **Leads CRM** (`leads.py`): CSV import, decision-maker inference, Google
  Places (New) + Yelp Fusion adapters, opt-out list.
- [x] **Lead extractor / Outbound** (`enrich.py`): robots-respecting crawl of
  homepage + contact pages; extracts emails, phones, social links; classifies
  personal vs generic emails; auto-runs after find-import.
- [x] **Phone / WhatsApp** (`phone.py`): E.164 + `wa.me` deep links.
- [x] **Outreach** (`outreach.py`): templates, follow-up cadence, opt-out
  footer, daily send limit, optional own-SMTP send, CSV export.
- [x] **Redirect finder** (`redirect.py`): follows HTTP redirects for a list of
  domains, records final URL, status, hop count and the full chain in a
  `redirect_checks` table; CLI `redirect check/list`, API
  `POST /api/redirect/check` + `GET /api/redirect`, "Research" tab.
- [x] **DNS history / nameserver checker** (`history.py`): RDAP registration
  age + registrar + nameservers, current NS via DNS-over-HTTPS (no new dep),
  crt.sh certificate history, Wayback first/last snapshot, and dropped-domain
  detection; stores `nameservers`/`created_date`/`dns_note`; CLI
  `history --domain`, API `GET /api/history` + `POST /api/history/check`.
  Every source degrades gracefully when unreachable.
- [x] **Web research -> contacts** (`research.py`): given a search query (e.g.
  `miami dentist`), searches the web via `hunter.web_search`, visits each result
  site once (robots-friendly, reusing `enrich.find_contacts`) and previews the
  email (personal vs generic), phone, `wa.me` WhatsApp link and socials it
  publishes; `import_results(domain_id, rows)` turns the picked rows into leads
  on the chosen domain, setting `email_status='scraped'` and copying socials.
  CLI `research --query [--limit --max-pages --import-domain]`; API
  `POST /api/research` + `POST /api/research/import`; "Research" tab panel
  (search table with checkboxes + import). No Google scraping; DuckDuckGo only.
- [x] **Web dashboard + CLI**: tabs Dashboard, Candidates, Generator,
  Inventory, Brandables, Leads, Outreach, Research, Settings.

Tests: `python3 -m unittest discover -s tests` (233 passing).

---

## Next tasks (in build order)

### [x] #4 Redirect Finder
Done: `redirect.py` (`normalize`, `check_one`, `check_domains`, `list_checks`),
`redirect_checks` table, CLI `redirect check --file|--domain` + `redirect list`,
`POST /api/redirect/check` / `GET /api/redirect`, "Research" tab. Follows the
chain via `net.get(... allow_redirects=True)`, no proxies; degrades to
`error="unreachable"` when a host is down.

### [x] #3 DNS History / Nameserver Checker
Done in `history.py`: `analyze(domain)` combines
- current nameservers via RDAP, falling back to DNS-over-HTTPS
  (`dns.google`) - no new dependency, keeps Flask+requests only;
- registration age / registrar / expiry from RDAP;
- certificate history from `crt.sh`;
- Wayback first/last snapshot, and dropped-domain detection
  (`archived before current registration`).
Stored on the domain row (`nameservers`, `created_date`, `dns_note`,
`history_note`, `wayback_snapshots`). CLI `history --domain`, API
`GET /api/history?domain=` + `POST /api/history/check`, "Research" tab panel.
Each source degrades to a note (`no-data`, `wayback-unreachable`) instead of
crashing.

### [x] #5 Maps / local business finder (compliant)
Done. Google Places + Yelp adapters need a user key; added a keyless fallback:
- OpenStreetMap in `leads.py`: `osm_search(city, niche)` geocodes the city via
  **Nominatim** then queries **Overpass** (`build_tag_query` indexed tag
  matches + `build_name_query` fallback), returning name/phone/website same
  shape as the Places adapter. Mirrors tried in `config.OVERPASS_URLS`; empty
  list on failure instead of crashing. Reuses `enrich.py` for emails/socials.
- CLI `lead find --provider osm` (default), API
  `POST /api/domains/<id>/find-contacts` with `provider="osm"`, UI Leads tab.
- Acceptance: search returns businesses without any API key (verified live:
  Miami dentist -> 15, hairdresser -> 10+); UI/CLI import them as leads.
- Note: Overpass can be slow/flaky on heavy queries; query defaults are kept
  light (10km, `shop/craft/amenity/office`) and degrade gracefully.

### [x] #11 End User Hunter
Done. `hunter.py` orchestrates a one-shot buyer hunt:
- `hunt(domain_id, city, niche, limit)` reads the domain row's `city`/`niche`
  when not given, gathers candidates from `leads.osm_search` (keyless) plus an
  optional web search (`web_search`: `ddgs` package if installed, else
  DuckDuckGo HTML `parse_ddg`), dedupes, skips businesses already on the
  domain (`leads.lead_exists`), imports them, then enriches contacts via
  `enrich.enrich_leads` and reports `templates` from `outreach.py`.
- CLI `hunter --domain-id [--city --niche --limit --no-web --no-enrich]`;
  API `POST /api/hunter`; "Hunt buyers" panel on the Leads tab.
- Acceptance: geo domain + city -> local businesses imported as leads (live:
  Miami dentist -> 8 imported); contacts enriched; 14 templates available.
- Compliance: OSM + public search only; no social automation.

### [separate] #6 + #7 Email Toolkit
Separate small project (new repo/folder), because it is generic:
- Validator: `email-validator` (syntax), `dnspython` (MX), throttled
  `smtplib` (SMTP RCPT), catch-all detection, disposable-list check.
- Finder: permutation generator (first.last, firstlast, f.last, first.l, ...)
  + optional SMTP verify; optional Hunter/Apollo free tiers via user key.
- Expose as CLI + optional tiny HTTP; this app can call it. Do NOT copy its
  logic into this repo.

---

## Refused / reframed (do not implement)

- **Bulk WhatsApp verification** — ToS violation / ban risk. Kept as manual
  `wa.me` deep links (`phone.py`).
- **Google Maps / Yelp browser scraping** — use official free-tier APIs or OSM.
- **Free-proxy rotation / "auto-fetch proxies"** — evasion tooling; unreliable.
  Use polite throttling instead (`net.py`, `enrich.py`).
- **LinkedIn / social automation scraping** — not allowed.
- **Email warm-up, multi-account rotation, volume spam** — CAN-SPAM/sender
  reputation. Kept: opt-out, daily limit, own mailbox.

---

## Handoff checklist for a new agent

1. Read `AGENTS.md` (stack, conventions, run/test).
2. Read this file; pick the first `[ ]` task in "Next tasks".
3. Implement module -> CLI -> API -> UI -> tests.
4. `python3 -m unittest discover -s tests` must stay green.
5. Restart `run.py`, verify the new endpoint with curl.
6. Update the status in this file and the file map in `AGENTS.md`.

Reference material (source playlist transcript + DeepSeek spec/summary) is in
`.monkeycode-tmp-files/` at authoring time but is gitignored — the durable
plan is THIS file, so keep it current.
