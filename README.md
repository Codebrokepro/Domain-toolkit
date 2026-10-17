# Geo-Domain Toolkit

A free, local-first toolkit for the geo-domain (`City + Service .com`) trading
workflow described in the playlists. It automates sourcing, qualification,
lead management, and outreach drafting. It runs entirely on your machine.

Nothing here costs money: the only network calls are to free public data
sources (GeoNames, Verisign RDAP, Wayback CDX) and, optionally, official free
tiers of Google Places / Yelp Fusion that you configure with your own keys.

## What it does

| Stage | Module | Free source |
|-------|--------|-------------|
| Cities | `cities.py` | GeoNames `cities15000` dump |
| Niches | `niches.py` | curated from the playlists |
| Sourcing | `generator.py` | city x niche -> `CityNiche.com` |
| Patterns | `patterns.py` | keyword, industry, CVCV, CVCVC, 4-letter non-CVCV, random, bulk list |
| Availability | `availability.py` | Verisign RDAP (`.com`) |
| History | `history.py` | Wayback CDX, RDAP, DoH, crt.sh |
| Redirects | `redirect.py` | HTTP redirect chains (no proxies) |
| Qualification | `scoring.py` | 15-criteria score, tier, price band |
| Leads CRM | `leads.py` | CSV import + Google Places / Yelp Fusion + OpenStreetMap (keyless) |
| End-user hunt | `hunter.py` | OSM + optional web search -> leads -> enrich |
| Inventory | `inventory.py` | ownership, expiry alerts, profit/renewal dashboard |
| Email finder | `enrich.py` | visits lead websites (robots-friendly) |
| Outreach | `outreach.py` | email templates, follow-up cadence, opt-out |
| Brandables | `brandable.py` | free wordlists + `.si` RDAP |
| Valuation | `godaddy.py` | official GoDaddy appraisal API (your free key) |

## Install

```bash
pip install -r requirements.txt
```

Python 3.9+ is required. Flask and requests are the only dependencies.

## Quickstart (run the whole thing)

```bash
pip install -r requirements.txt
python3 run.py                 # then open http://localhost:5000
```

First run in the dashboard, or via CLI:

```bash
python3 -m geodomain.cli init
python3 -m geodomain.cli cities import --country US --min-pop 150000
python3 -m geodomain.cli pipeline --country US --min-pop 150000 --max 2000 --check-limit 500
```

Everything works with **no keys** (GeoNames, RDAP, OSM, enrich, outreach
drafts). Keys are optional and only unlock extra sources.

## Configuration: settings & API keys

All keys live in the `settings` table, edited on the dashboard **Settings** tab
(or `GET`/`POST /api/settings`). Nothing is hardcoded, and the DB is gitignored,
so keys never enter the repo.

| Setting key | Optional? | Where to get it | Unlocks |
|-------------|-----------|-----------------|---------|
| `sender_name` | yes | your name | email signature |
| `from_email` | yes | your mailbox | From header |
| `daily_send_limit` | yes (default 40) | your choice | send cap (`outreach.py`) |
| `smtp_host` / `smtp_port` / `smtp_username` / `smtp_password` | yes | your email provider | real sending; without it, send is a dry run |
| `google_places_api_key` | yes | Google Cloud (free tier) | Google Places leads |
| `yelp_api_key` | yes | Yelp Fusion (free tier) | Yelp leads |
| `godaddy_api_key` / `godaddy_api_secret` | yes | https://developer.godaddy.com | the Valuation column |

No key is required for: city import, generation, availability, scoring,
history, redirects, OSM lead search, the buyer hunt, email enrichment, and
outreach drafting/export.

## Web dashboard

```bash
python3 run.py
```

Then open http://localhost:5000. The dashboard has tabs for the dashboard,
candidates, generator, inventory, brandables, leads, outreach, research, and
settings.

## CLI

```bash
# create the database
python3 -m geodomain.cli init

# download and ingest cities (US cities above 150k population)
python3 -m geodomain.cli cities import --country US --min-pop 150000

# generate city x niche candidates
python3 -m geodomain.cli generate --country US --min-pop 150000 --city-limit 40 --max 2000

# add a niche you just found and generate City+Niche for EVERY city
# (saved to data/niches.csv, so it stays in the catalog)
python3 -m geodomain.cli niches add electricalservices --group home --strength 7
python3 -m geodomain.cli generate --niche electricalservices --all-cities --max 0 --remember

# check .com availability via RDAP and score everything
python3 -m geodomain.cli check --limit 500

# DNS / age / history for a single domain (RDAP + DoH + crt.sh + Wayback)
python3 -m geodomain.cli history --domain example.com

# list the best available candidates
python3 -m geodomain.cli domains --available --tier WATCH --limit 30

# one-shot: generate + check + score
python3 -m geodomain.cli pipeline --country US --min-pop 150000 --max 2000 --check-limit 500

# add a lead and compose an email
python3 -m geodomain.cli lead add --domain-id 12 --name "Joe's Plumbing" --email joe@example.com --title Owner
python3 -m geodomain.cli compose --lead-id 1 --stage 0
python3 -m geodomain.cli export --domain-id 12 --stage 0 --out drafts.csv
```

## Scoring

Each candidate gets a 0-100 score from automatically available criteria
(extension, structure, word/character length, country, niche strength,
specificity, city population, reverse-order validation) plus optional
enrichment you enter yourself (search volume, CPC, Google Maps pages, Yelp
pages, GoDaddy appraisal, NameBio notes, Wayback history).

| Tier | Meaning |
|------|---------|
| `BUY` | score >= 75, available, strong on every axis |
| `WATCH` | score 58-74, re-check later |
| `SKIP` | score < 58 |
| `TAKEN` | domain is registered |
| `UNCHECKED` | not yet queried |

Estimated outbound price bands are derived from score and niche group
multiplier, following the 10x-30x rule of thumb from the playlists.

## Domain generator (patterns)

The **Generator** tab (and `patterns` CLI command) mass-produces names beyond
the geo `City + Niche` idea, then checks availability via RDAP and scores them
with the same pronounceability/length model used for the brandables:

- **CVCV** and **CVCVC** - strict consonant/vowel patterns (`novu`, `kirem`),
  the classic short brandable shapes.
- **4 letters (non-CVCV)** - every 4-letter shape except the CVCV pattern
  (`noncvcv`). Since almost all pronounceable CVCV `.com`s are registered,
  this widens the search to the far larger set of remaining combinations.
- **Keyword** - a keyword, optionally combined with prefixes/suffixes
  (`nova`, `getnova`, `novaly`).
- **Industry** - every niche in the catalog, with optional affixes.
- **Random** - pronounceable random strings within a length window.
- **Bulk list** - paste or import an existing list of domains to check.

All free: RDAP for availability, no paid registrar API required. Results are
stored as `kind='pattern'` and kept separate from the geo candidates.

```bash
# 1500 CVCVC .com names, checked and scored
python3 -m geodomain.cli patterns generate --mode cvcvc --count 1500 --check-limit 1500

# keyword blends
python3 -m geodomain.cli patterns generate --mode keyword --keywords nova,swift \
  --prefixes get,go --suffixes ly,hq --count 800

# only the available ones, best first
python3 -m geodomain.cli patterns list --available --limit 30

# check an existing list (one domain per line)
python3 -m geodomain.cli patterns bulk domains.txt
```

## Domain inventory, expiry alerts, profit

Beyond finding names, the toolkit tracks the ones you own. The **Inventory**
tab (and the `inventory` CLI command) records registrar, purchase and expiry
dates, cost, target and minimum price, renewal price, where it is listed, and
status (`owned`, `listed`, `negotiating`, `sold`, `kept`).

It then gives you:

- **Expiry alerts** - domains sorted by how soon they expire, bucketed into
  30 / 60 / 90 days and already-expired, so a renewal is never missed.
- **Profit pipeline** - total cost, target value, expected profit on open
  domains, realized profit on sold ones, and annual renewal cost.
- **Registrar breakdown** - how many domains and how much renewal spend per
  registrar.

Any domain with an inventory detail (or status `owned`/`listed`/`sold`/
`negotiating`) counts as inventory; plain candidates stay out of the numbers.

```bash
# overview: cost, expected/realized profit, renewal, expiry buckets
python3 -m geodomain.cli inventory dashboard

# what is expiring in the next 30 days
python3 -m geodomain.cli inventory expiring --days 30

# record ownership details for domain id 12
python3 -m geodomain.cli inventory set 12 --registrar GoDaddy --cost 9 \
  --target-price 2500 --purchase-date 2025-11-17 --expiry-date 2026-11-17 --status owned

# list inventory
python3 -m geodomain.cli inventory list --status owned
```

## Brandable `.si` finder

The geo pipeline buys `City + Service .com` names. The brandable finder hunts a
different asset: short, meaningful words on Slovenia's `.si` ccTLD, read as
"SI" for **superintelligence**. The `.ai` extension is the precedent - one-word
names became valuable once the AI wave hit. `.si` is the same play at a lower
price, and the toolkit measures "hotness" from data instead of guessing.

How a candidate is judged:

- **Word source (free)**: `google-10000-english.txt` (frequency) and
  `words_alpha.txt` (dictionary) from public GitHub wordlists, plus a curated
  AI/superintelligence theme list. One-word names are generated first, then
  optional two-word prefix/suffix blends (`getX`, `Xai`, `Xlabs`, ...).
- **Scoring**: length, 1-word vs 2-word, dictionary membership,
  pronounceability (vowel ratio and consonant runs) and AI theme membership.
- **Availability**: the `.si` itself is checked live through `rdap.register.si`.
  No lookups are made for other extensions.

Tiers: `BUY >= 72`, `WATCH >= 55`, then `SKIP` / `TAKEN` / `UNCHECKED`.

```bash
# generate 1-word candidates, check .si availability, score them
python3 -m geodomain.cli brandable pipeline --limit 500 --check-limit 500

# include two-word blends as well
python3 -m geodomain.cli brandable pipeline --two-word --limit 800

# re-check pending candidates, then list the best
python3 -m geodomain.cli brandable check --limit 500
python3 -m geodomain.cli brandable list --available --min-score 72 --limit 30
```

In the dashboard, open the **Brandables (.si)** tab, tick *1-word* and/or
*2-word*, set the length window and a check cap, and click **Run**. Results are
filterable by tier and show each candidate's score and price band. The
**Open** button loads it into the same leads / outreach workflow as geo names.
Runs are incremental: labels already stored for that TLD are skipped, so
clicking **Run** with Count 400 again adds the next 400 unseen candidates.

## Finding buyer emails for free

Google Places and Yelp return business names, phones and websites but not email
addresses. Instead of paying per-lookup tools, the toolkit visits each lead's
own website (homepage plus a contact/about page) and reads the email address it
publishes publicly. It is free and unlimited, but polite:

- checks `robots.txt` before fetching and skips disallowed pages
- one request per second per host, at most three pages per site
- filters out `noreply@`, `postmaster@`, image filenames, placeholder domains
- prefers an address on the same domain as the website

In the web dashboard, load a domain under **Leads** and click **Extract emails
from lead websites**. Lead websites can come from Google Places, Yelp, or a CSV
import. Email extraction runs **automatically** after **Find & import** and
after CSV import (untick *auto-extract emails* to disable), and can be run in
bulk at any time with the button or `python3 -m geodomain.cli enrich`.

## Finding leads for free (OpenStreetMap, no key)

Beyond Google Places / Yelp (which need your own free-tier key), the toolkit
finds local businesses with **zero keys** using OpenStreetMap:

- Geocodes the city with **Nominatim**, then queries **Overpass** for matching
  businesses (`shop` / `craft` / `amenity` / `office` tags, with a niche->tag
  alias table such as `plumbing` -> `plumber`).
- Returns the same lead shape (name / phone / website / address), so the normal
  enrich -> outreach flow applies. Mirrors and failures degrade to an empty
  list instead of crashing.

```bash
python3 -m geodomain.cli lead find --provider osm --city Miami --niche dentist --limit 20
```

Dashboard: **Leads** tab -> *Find leads automatically* -> provider
*OpenStreetMap (free, no key)*. API:
`POST /api/domains/<id>/find-contacts` with `{"provider":"osm", ...}`.

### Foursquare Open Source Places (keyless)

Provider `foursquare` reads the free, openly licensed **Foursquare OS Places**
dataset from a local file, so no API key or live quota is used. The adapter
looks for `data/cache/fsq_places.jsonl` (one JSON object per line) or
`data/cache/fsq_places.json` (a JSON array).

Each record should expose `name`, `locality`, `tel`, `website`, `address` and
`categories` (`[{"category_name": "Dentist"}]`). To refresh the cache, download
the open dataset from Foursquare's OS Places distribution
(https://location.foursquare.com/products/places/), convert the rows you need
to that JSON/JSONL shape, and drop the file in `data/cache/`. The city and
niche are matched against `locality`/`categories` (`FSQ_CATEGORY_MAP` in
`leads.py`). If the file is missing or unreadable the provider returns `[]`
and the app keeps working.

CLI: `python3 -m geodomain.cli lead find --provider foursquare --city Miami --niche dentist`

## End-user hunter

`hunter.py` does a one-shot buyer hunt for a domain: it reads the domain's city
and niche, gathers candidates from OpenStreetMap plus an optional web search,
skips businesses already on the domain, imports the rest as leads, then
enriches their contacts. It also reports how many outreach templates exist.

```bash
python3 -m geodomain.cli hunter --domain-id 12 --limit 20
python3 -m geodomain.cli hunter --domain-id 12 --no-web --no-enrich   # OSM only, fast
```

Dashboard: **Leads** tab -> *Hunt buyers*. API: `POST /api/hunter` with
`{"domain_id":12,"city":"Miami","niche":"dentist","limit":20}`.

The optional web step uses the `ddgs` package if installed, otherwise the
DuckDuckGo HTML endpoint; if both are unavailable it silently falls back to
OpenStreetMap only.

## Web research (search -> contacts)

`research.py` inverts the workflow: instead of starting from a domain, you start
from a search query such as `miami dentist`. It runs the query through the same
free DuckDuckGo search the hunter uses, visits each result site **once**
(robots-friendly, reusing the `enrich` crawler), and shows the email (flagged
personal or generic), phone, a one-click `wa.me` WhatsApp link and the socials
each site publishes - so you don't open every result by hand. Results are a
preview; import the ones you want into any domain's leads.

```bash
python3 -m geodomain.cli research --query "miami dentist" --limit 10
python3 -m geodomain.cli research --query "austin plumber" --import-domain 12
```

Dashboard: **Research** tab -> *Search &rarr; contacts*. API: `POST /api/research`
with `{"query":"miami dentist","limit":10}` and `POST /api/research/import` with
`{"domain_id":12,"results":[...]}`. No Google scraping, no proxies.

## Redirects & DNS history

- **Redirect finder** (`redirect.py`): follows each domain's HTTP redirect
  chain and records the final URL, status and hop count in `redirect_checks`.
  CLI `redirect check --domain|--file` + `redirect list`;
  API `POST /api/redirect/check` + `GET /api/redirect`; **Research** tab.
- **DNS history** (`history.py`): RDAP registration age/registrar/NS, current
  nameservers via DNS-over-HTTPS, crt.sh certificate history and Wayback
  snapshots. CLI `history --domain`; API `GET /api/history` +
  `POST /api/history/check`. Every source degrades to a note when unreachable.

## WhatsApp links

Most local businesses publish a phone number, not an email. The toolkit
normalizes each lead's phone number to E.164 and shows a one-click **WhatsApp
chat** link (`https://wa.me/<number>`) as a `wa.me` deep link. Clicking it opens
WhatsApp with that number; WhatsApp itself reports whether the number is
registered. This is the official, safe way to reach a number manually.

It does **not** batch-check whether numbers are on WhatsApp. That requires
either a paid official provider or an unofficial WhatsApp Web client, and bulk
number validation through unofficial clients violates WhatsApp's terms and is a
spam-enabling pattern. The `wa.me` link approach keeps your account safe.

## Domain valuation (GoDaddy appraisal)

Both the Candidates and Brandables tables have a **Valuation** column. Until a
real appraisal is fetched it shows the toolkit's own score-based price band as
an estimate.

For an actual number, add a GoDaddy API key and secret in **Settings**. Create
them for free at https://developer.godaddy.com (a GoDaddy account is required).
The toolkit then calls the official endpoint
`https://api.godaddy.com/v1/appraisal/{domain}` with your key. There is no
scraping involved.

- Buttons: **Appraise shown (GoDaddy)** on each tab, or
  `python3 -m geodomain.cli appraise --kind geo --limit 25`.
- Without a key, appraisal is skipped and the estimate stays.
- GoDaddy does not appraise every TLD. `.com` names work; many ccTLDs,
  including `.si`, may return "not appraisable" - those keep the estimate.
- Atom (formerly Squadhelp) has no public appraisal API, so Atom values can
  only be entered manually (the **Open** dialog's GoDaddy field accepts any
  number you type).

## Compliance notes

This toolkit deliberately avoids the abusive patterns in the playlists:

- No scrapers that violate Google Maps / Yelp terms of service. Lead data
  comes from CSV import or the official, authorized free-tier APIs.
- No email "warm-up" automation, no multi-account rotation, and no volume
  designed to evade spam filters. Sending is done through your own mailbox
  (SMTP) or by exporting drafts.
- Outreach is CAN-SPAM oriented: a working opt-out line is appended to every
  email, an opt-out list suppresses addresses, and a daily send limit is
  enforced.

## Data sources

- GeoNames - http://download.geonames.org/export/dump/ (CC BY 4.0)
- Verisign RDAP - https://rdap.verisign.com/com/v1/domain/
- `.si` RDAP - https://rdap.register.si/domain/
- Wayback CDX - https://web.archive.org/cdx/search/cdx
- Wordlists - `google-10000-english` and `dwyl/english-words` (public GitHub)

## Tests

```bash
python3 -m unittest discover -s tests -v
```
