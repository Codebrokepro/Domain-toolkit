# BACKLOG — Compliant additions (handoff)

Purpose: keep every feature of the 12 playlist tools while replacing only the
abusive/banned mechanisms. Base app is feature-complete against `ROADMAP.md`
(220 tests green). This file is the next work queue.

Conventions (see `AGENTS.md`): Python 3.9+, Flask + requests only, SQLite,
vanilla JS. For every item: implement module -> CLI subcommand in `cli.py` ->
JSON route(s) in `web.py` -> UI in `static/index.html` + `static/app.js` ->
unit tests in `tests/test_core.py`. Schema changes go in BOTH `SCHEMA` and
`MIGRATIONS` in `db.py`. Run `python3 -m unittest discover -s tests` after each
item; then restart `run.py` and `curl` the endpoint.

Compliance rule for ALL items below: no paid APIs, no browser scraping of
Google Maps/Yelp/LinkedIn, no bulk WhatsApp presence probing, no proxy pools
for evasion, no warm-up/multi-account/blast tooling. Use official free tiers
(user key), public keyless open data (OSM), the user's own mailbox, and
manual/opt-in outreach.

Legend: [ ] todo. Group letter = workstream.

---

## A. Outreach deliverability & compliance
Refused item: "email warm-up, multi-account rotation, volume spam".
We keep: own SMTP, templates, follow-ups, opt-out, daily cap. Add the
professional-but-legit pieces that actually help deliverability.

- [x] A1. `List-Unsubscribe` headers
  - File: `geodomain/outreach.py` (`smtp_send`).
  - Set `msg["List-Unsubscribe"]` and `msg["List-Unsubscribe-Post"]="List-Unsubscribe=One-Click"`.
  - Value from a new Settings key `unsubscribe_mailto` (defaults to `from_email`
    with subject `unsubscribe`). Skip header if not set.
  - Acceptance: unit test asserts headers present on the built message;
    `POST /api/outreach/send` returns success in dry-run.

- [x] A2. Send-time window
  - Files: `outreach.py` (`smtp_send`), `web.py` settings, UI Settings tab.
  - Settings `send_window_start`/`send_window_end` (hour 0-23, local) and
    `send_days` (csv of 0-6). Refuse send outside the window with
    `{"sent": False, "reason": "outside_window"}`.
  - Acceptance: test with monkeypatched `datetime` inside/outside window.

- [x] A3. Bounce capture + suppression
  - Files: `db.py` (new `bounces` table: id, lead_id, email, reason, created_at),
    `outreach.py` (`record_bounce(email, reason)` + set lead `email_status='bounced'`
    and add to `optouts`), `web.py` `POST /api/outreach/bounce`.
  - `smtp_send` skips addresses with `email_status='bounced'`.
  - Acceptance: recording a bounce suppresses future sends to that address.

- [x] A4. One-click unsubscribe endpoint
  - Files: `web.py` `GET/POST /api/unsubscribe?email=...` -> `leads.add_optout`,
    tiny static confirm page; `outreach.py` reuses it for the `List-Unsubscribe` URL.
  - Acceptance: GET then `leads.is_opted_out(email)` is True; `export_drafts`
    excludes them.

- [x] A5. Domain-auth self-check (SPF/DKIM/DMARC guidance)
  - Files: new `geodomain/mailcheck.py` using `net` + DNS-over-HTTPS
    (`config.DOH_URL`, type=TXT) — no new dependency.
  - `check_domain(from_domain)` returns whether SPF/DMARC TXT records exist and
    the DMARC policy; surfaces advisory text only (never sends).
  - CLI `mailcheck --domain`; API `GET /api/mailcheck?domain=`; Settings "Email
    health" panel.
  - Acceptance: parse tests for SPF/DMARC TXT fixtures; graceful `no-data`.

- [x] A6. Per-minute spacing / jitter
  - File: `outreach.py`. Add Settings `send_interval_seconds` (default 30) and
    jitter; track last send in `settings` or a small in-process lock.
  - Acceptance: two rapid `smtp_send` dry-runs report `throttled` for the second.

- [x] A7. List hygiene before export/send
  - File: `outreach.py` (`export_drafts`, `smtp_send`) + `enrich.py` classifier.
  - Dedupe by lower(email); drop `BAD_PREFIXES`/`BAD_EMAIL_DOMAINS`, disposable
    domains, and opted-out. Report counts in the return payload.
  - Acceptance: fixture list with dupes/bad/opt-out yields expected counts.

---

## B. Email Toolkit bridge (#6/#7 done in a separate project)
The app must CALL the separate toolkit, not reimplement it. Provide a
zero-dependency fallback so the app still works if the toolkit is absent.

- [x] B1. Adapter `geodomain/emailtool.py`
  - Settings: `email_toolkit_cmd` (shell command) or `email_toolkit_url` (HTTP).
  - `validate(email)` -> {status: valid|invalid|unknown, reason}; tries URL, then
    cmd (expects JSON on stdout), then built-in fallback.
  - `find(first, last, domain, patterns=None)` -> candidate list (delegates).
  - Compliance: no sending, no verification against third-party mailboxes.
  - Acceptance: with a fake URL/cmd (mock), returns parsed JSON.

- [x] B2. Built-in fallback validator (no new dep)
  - File: `emailtool.py`. Syntax regex + MX lookup via DoH (`type=MX`) +
    disposable list (`config` constant). Set lead `email_status`.
  - Acceptance: invalid syntax -> invalid; domain with no MX -> invalid.

- [x] B3. Wire into leads/outreach
  - Files: `leads.py` (`email_status`), `outreach.py` (skip status invalid/bounced),
    CLI `email validate --email`, API `POST /api/email/validate`, Leads UI column
    action "validate".
  - Acceptance: validating a lead flips `email_status`; export skips invalid.

---

## C. Lead-source expansion
Refused item: "Google Maps / Yelp browser scraping". We already use official
APIs + keyless OSM; add more keyless/open sources behind a registry.

- [x] C1. Provider registry
  - File: `leads.py`. `PROVIDERS = {"osm": osm_search, "google_places": ...,
    "yelp": ..., "foursquare": ...}`; `search(provider, city, niche, key, limit)`.
  - `web.py` find-contacts and `hunter.py` use the registry.
  - Acceptance: unknown provider -> clean error; registry dispatch test.

- [x] C2. Foursquare Open Source Places adapter
  - File: `leads.py` (+ `config` dataset URL if needed). Keyless open dataset.
    Map niche -> FSQ category; return the same lead shape.
  - Doc: how to obtain/refresh the dataset; cache under `data/cache/`.
  - Acceptance: parse fixture -> leads; degrade to `[]` offline.

- [x] C3. Overpass category presets
  - File: `leads.py` (`OSM_TAG_ALIASES` -> expand to `NICHE_OSM_TAGS` mapping many
    niches to explicit tag sets: e.g. dentist=amenity/dentist, lawyer=office/lawyer,
    car_repair=shop/car_repair).
  - Acceptance: preset lookup test; query builder uses preset when present.

- [x] C4. Google Places (New) pagination + details
  - File: `leads.py` `google_places_search`. Follow `nextPageToken` up to limit;
    optional Place Details for `websiteUri`/`nationalPhoneNumber`.
  - Key from Settings `google_places_api_key`.
  - Acceptance: mocked two-page response returns combined results.
  Done: `google_places_search` loops `nextPageToken`, stops at `limit`, dedupes
  by name; `google_place_details(place_id, api_key)` fills missing
  phone/website when `with_details=True`. Registry `search(..., with_details=)`,
  API body `with_details`, CLI `lead find --details`, Leads UI checkbox.
  `hunter.hunt` now resolves the provider key from Settings so keyed providers
  work there too. Tests: `TestGooglePlaces` (pagination, limit, dedupe,
  details skip/fill, no-key, error) + registry forwarding.

- [x] C5. Yelp categories mapping
  - File: `leads.py` `yelp_search`. Map niche -> Yelp category alias; support `categories`.
  - Acceptance: URL/param builder test.
  Done: `YELP_CATEGORY_ALIASES` (synonyms) + `NICHE_YELP_CATEGORIES` (canonical)
  -> `yelp_category(niche)` / `yelp_categories(niche, extra)`; `build_yelp_params`
  merges the mapped alias with user `categories` (deduped, lowercased) and caps
  `limit` at 50. `yelp_search(..., categories=)` uses the builder; registry
  `search(..., categories=)`, API body `categories`, CLI `lead find --categories`,
  Leads UI "Yelp categories" input. Tests: `TestYelpCategories` + `TestYelpSearch`.

- [x] C6. Nominatim POI fallback (permission-safe)
  - File: `leads.py`. When Overpass fails, query Nominatim `search?q=<niche> <city>`
    and parse `extratags` for phone/website.
  - Acceptance: parse fixture; used only when Overpass yields nothing.

---

## D. Social / contact enrichment (non-automated)
Refused item: "LinkedIn / social automation scraping". Keep: public links only.

- [x] D1. Normalize social handles
  - Files: `enrich.py` + `leads.py`. Strip tracking params, canonicalize
    (x.com -> twitter), store handle.
  - Acceptance: normalization tests.
  Done: `enrich.normalize_social` strips the query/tracking params, maps
  `x.com`/`fb.com`/`youtu.be` to canonical hosts, drops `www.`, and extracts a
  handle (reserved share/intent paths excluded). `enrich.normalize_socials`
  batch-normalizes; `leads.normalize_socials` rewrites stored URLs and merges
  handles into `leads.social_handles` (schema + migration). CLI
  `lead normalize-socials`, API `POST /api/leads/normalize-socials`, Leads UI
  "Normalize socials" button. Tests: `TestSocialNormalization` +
  `TestLeadNormalizeSocials`.

- [x] D2. LinkedIn company-page guess (no scraping)
  - File: `enrich.py`. From a business website/name, construct a *candidate*
    LinkedIn search URL for manual use; never fetch/parse LinkedIn.
  - Acceptance: returns a search URL only.
  Done: `enrich.linkedin_query(business_name, website)` +
  `enrich.linkedin_search_url(...)` build a `/search/results/companies/?keywords=`
  URL (falls back to the website label when the name is missing). No request is
  ever made to LinkedIn. CLI `linkedin --business/--website`, API
  `GET /api/linkedin`, Leads UI "in" button opens the search in a new tab.
  Tests: `TestLinkedIn` + `TestLinkedInApi`.

- [x] D3. YouTube Data API (optional, user key)
  - File: new `geodomain/social.py` or extend `enrich.py`. Free tier, user key in
    Settings `youtube_api_key`; channel/subscriber info for a found channel.
  - Acceptance: mocked response; skip silently without key.
  Done: `social.parse_channel` / `channel_info(handle=, channel_id=, api_key=)`
  call the free `/youtube/v3/channels` endpoint via `net.try_get` and return
  title/handle/country/subscribers/videos/views; `channel_for_lead(lead_id)`
  reuses the lead's stored `social_handles.youtube` (falling back to
  `enrich.normalize_social` on the `leads.youtube` URL). No key -> `no_key` with
  no network call; unreachable/not_found degrade to an error dict. Key kept in
  Settings (`stYt`, never hardcoded). CLI `youtube --handle|--channel-id|--lead-id
  [--api-key]`; API `GET /api/youtube?handle=` + `POST /api/youtube/lead`; Leads
  UI "YT" button (shown only when the lead has a channel). Tests: `TestYouTube`
  (parse, no-key skip, mocked response, not_found, unreachable, lead handle,
  no-youtube lead, API 400).

---

## E. WhatsApp — keep, but manual/opt-in
Refused item: "bulk WhatsApp verification".

- [x] E1. Pre-filled WhatsApp message
  - Files: `phone.py` (already supports `?text=`), `outreach.py` (build a short
    WhatsApp variant), `static/app.js` (use it for the "chat" link), Leads UI.
  - Acceptance: `whatsapp_link` includes encoded text; UI link opens with text.
  Done: `outreach.WHATSAPP_TEMPLATE` + `whatsapp_text(lead, domain)` +
  `compose_whatsapp(lead_id)` return `{phone, whatsapp_number, text, link}` where
  `link` is a `wa.me` URL with the encoded text. CLI `whatsapp --lead-id`; API
  `GET /api/leads/<id>/whatsapp` (404 missing lead, 400 no phone). Leads UI
  "chat" button fetches the pre-filled link and opens it. Tests:
  `TestWhatsAppCompose`.

- [x] E2. Copy-to-clipboard for WhatsApp
  - File: `static/app.js` + `index.html`. Button copies the drafted message.
  - Acceptance: manual UI check; no network call.
  Done: Leads UI "copy" button fetches the same message via the API and uses
  `navigator.clipboard.writeText`, falling back to a prompt when the clipboard
  API is unavailable (no separate network call beyond the existing GET).

- [x] E3. (Optional, opt-in only) WhatsApp Business Cloud API adapter
  - File: new `geodomain/whatsapp.py`. Sends ONLY to numbers that opted in;
    user's own token in Settings. No presence probing, no bulk.
  - Acceptance: dry-run returns payload; documented opt-in requirement.
  Done: `whatsapp_optins` table + `add_optin`/`remove_optin`/`is_opted_in`/
  `list_optins`; `send(to, message, dry_run=True)` refuses non-opted-in numbers
  (`not_opted_in`), returns the Graph payload on dry-run, and posts to
  `graph.facebook.com/v19.0/{phone_number_id}/messages` only when
  `dry_run=False` and the user's `whatsapp_token`/`whatsapp_phone_number_id`
  Settings are present. No presence probing, no bulk loop. CLI `whatsapp-optin`
  (`--number/--remove/--list`) + `whatsapp-send` (dry-run unless `--send`); API
  `POST /api/whatsapp/optin`, `GET /api/whatsapp/optins`,
  `POST /api/whatsapp/send`; Leads UI "opt-in" button; Settings token/ID fields.
  Opt-in requirement documented in the Settings hint. Tests:
  `TestWhatsAppCloudApi`.

---

## F. Networking politeness (replaces proxy rotation)
Refused item: "free-proxy rotation / auto-fetch proxies". We keep throttling.

- [x] F1. Retry with exponential backoff + jitter
  - File: `net.py`. Retry on 429/5xx/timeouts, cap attempts, honor `Retry-After`.
  - Acceptance: mocked responses -> retries counted.

- [x] F2. TTL disk cache for GETs
  - Files: `net.py` + `config` (`data/cache/`). Cache RDAP/DoH/robots with TTL;
    bypass flag. Reduces load and speeds reruns.
  - Acceptance: second call served from cache (no network).

- [x] F3. Optional single user-owned proxy
  - Files: `net.py` + Settings `http_proxy`. One proxy the user owns; NOT a pool.
  - Acceptance: session configured when set; disabled by default.
  Done: `net.configure_proxy(url)` sets `_SESSION.proxies` for http+https (or
  clears them); `net.configure_proxy_from_settings()` reads the `http_proxy`
  Setting. Wired into `web.create_app()` at startup and `POST /api/settings`.
  Disabled (empty proxies) when unset. Settings UI "Networking" field. Tests:
  `TestProxy`.

- [x] F4. robots.txt cache
  - File: `enrich.py` `_robots_allows`. Cache per host for the run.
  - Acceptance: robots fetched once per host.

---

## G. Robustness & infrastructure

- [x] G1. Configurable Overpass mirrors/timeout in Settings
  - Files: `config.py`, `web.py`, `leads.py`. Keys `overpass_urls` (csv),
    `overpass_timeout`. Defaults unchanged.
  - Acceptance: override changes `build`/`_run_overpass` behavior in test.

- [x] G2. Background jobs for long hunts
  - Files: `db.py` (`jobs` table), new `geodomain/jobs.py`, `web.py`
    `POST /api/jobs`, `GET /api/jobs/<id>`; UI poll. Prevents 60-120s blocking
    requests (Overpass can be slow).
  - Acceptance: job transitions queued->running->done; result retrievable.

- [x] G3. Full dataset export/import (JSON)
  - Files: new `geodomain/backup.py`, CLI `backup export|import`, API routes.
  - Acceptance: round-trip preserves counts for domains/leads/outreach.

- [x] G4. Request-level rate limiting for the local API
  - File: `web.py`. Simple in-memory limiter for expensive routes
    (find-contacts, hunter, history).
  - Acceptance: 2nd immediate call returns 429.

---

## H. UX / dashboard

- [x] H1. Bulk lead actions
  - Files: `web.py` `POST /api/leads/bulk`, UI Leads tab. Actions: set status,
    mark DNC (adds opt-out), set source. No hard delete (per rules).
  - Acceptance: bulk DNC adds opt-outs and flips status.

- [x] H2. Pipeline/financial chart
  - Files: Dashboard tab, `service.stats`/`inventory` data. Simple inline SVG or
    CSS bars (no new JS dep).
  - Acceptance: renders with seeded data.

- [x] H3. Global search
  - Files: `web.py` `GET /api/search?q=`, header search box.
  - Acceptance: finds domains and leads by substring.

- [x] H4. Provider/limit controls in Hunter UI
  - File: `static/app.js` + `index.html`. Expose provider selection + OSM-only
    toggle (already partly present via `--no-web`).
  - Acceptance: manual UI check.

---

## I. Search-first research (query -> contacts)

- [x] I1. `research.py`
  - File: new `geodomain/research.py`. `search(query, limit, max_pages)` runs
    `hunter.web_search`, visits each unique result host once via
    `enrich.find_contacts`, and returns business/website/host/email(+kind)/
    phone/whatsapp/socials rows; `contacts_for_website` reuses `phone.whatsapp_link`;
    `import_results(domain_id, rows)` dedupes via `leads.lead_exists` and creates
    leads (`email_status='scraped'`, socials copied).
  - CLI `research --query [--limit --max-pages --import-domain]`; API
    `POST /api/research` (rate-limited) + `POST /api/research/import`; "Research"
    tab panel. No Google scraping; DuckDuckGo + OSM only.
  - Acceptance: unit tests for contacts, search dedupe/limit, import
    create/skip/empty, and the API round-trip. Tests: `TestResearchContacts`,
    `TestResearchSearch`, `TestResearchImport`, `TestResearchApi`.

---

## Suggested order
1. A1, A2, A3, A4 (deliverability + compliance; small, high value)
2. B1, B2, B3 (bridge #6/#7 + fallback)
3. C1, C3, C6 (source registry + OSM presets + Nominatim fallback)
4. F1, F2, F4 (net politeness)
5. G1, G2 (Overpass robustness + background jobs)
6. D*, E*, H* as desired

## Definition of done for every item
- Unit tests added; full suite green (`python3 -m unittest discover -s tests`).
- CLI + API + UI wired where the item is user-facing.
- `ROADMAP.md` status and `AGENTS.md` file map updated if new files appear.
- `curl` proof recorded (endpoint returns expected JSON).
