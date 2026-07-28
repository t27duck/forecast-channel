# README

Forecast is a web-based implementation of the Nintendo Wii's Forecast Channel.

### Disclaimers

1. This is a personal experiement in agentic coding. Clude Opus is the primary model used.

2. No copyrighted material is included in this repo. For sounds, you must provide your own MP3 files.

3. Wii hand cursors are from the [Wii Homebrew Cursors](https://wiibrew.org/wiki/Wii_Homebrew_Cursors) created by drmr as public domain.

## Getting started

```bash
bundle install
npm install
bin/rails db:prepare
bin/dev              # http://localhost:3000
```

## Configuration

Secrets live in the environment. [dotenv](https://github.com/bkeepers/dotenv)
loads them on boot from `.env.<environment>.local`; every file is gitignored,
and blank templates are checked in:

- `.example.env.development.local` → copy to `.env.development.local` for local
  work. Only `MAPBOX_TOKEN` (the globe's Mapbox access token) is needed.
- `.example.env.production.local` → copy to `.env.production.local` for
  deploys. It drives the whole Kamal config — see **Deployment** below.

`db:seed` loads a curated set of major world cities (geocoding data baked into
`db/seeds.rb`, so it needs no network) so the globe is populated on a fresh
database. It's idempotent, and only sets each city's location/metadata — their
weather is filled in by the scheduled refresh (`bin/jobs`, or "Refresh all" in
the locations UI).

## Mapbox confirtuation

The globe needs a Mapbox access token in the `MAPBOX_TOKEN` environment variable:

```bash
cp .example.env.development.local .env.development.local   # then fill in MAPBOX_TOKEN=pk....
```

Without one the globe still builds — markers, controls and all — on an offline
style with no satellite imagery, which is how CI and the test suite run it.

## Locations

Managing locations is admin-only. The app has a single sign-in (username +
password, via the Rails auth generator). In **development**, `bin/rails db:seed`
creates an `admin` / `testing123` account. For **production**, create the admin
in the console:

```bash
bin/rails runner 'User.create!(username: "admin", password: "a-strong-password")'
```

Only the location-management actions are protected — the forecast, globe, and
settings views are public. Manage locations at `/locations`:

- **New location** searches by place name (powered by the free Open-Meteo
  geocoding API — no API key required), captures the latitude/longitude and
  location metadata, and lets you review before saving.
- Each location also stores cached weather (current conditions, UV, today/
  tomorrow forecasts, 6-hour windows, and a 5-day forecast), fetched from the
  free Open-Meteo forecast API, plus current air quality (US AQI, PM2.5) from
  the free Open-Meteo air-quality API.

## Weather refresh

Cached weather is fetched from Open-Meteo and refreshed periodically:

- **Manually**: on `/locations`, use a row's "Refresh" button (immediate) or
  "Refresh all" (enqueues background jobs).
- **Automatically**: two schedules in `config/recurring.yml` — the **hot** tier
  (the biggest cities plus anywhere viewed in the last week) refreshes hourly,
  and everywhere else every 6 hours.
- **On arrival**: the splash screen at `/` refreshes your own location if its
  weather has gone stale, so what you see on opening the app is current.

Requests are **batched**: up to 50 locations are fetched per HTTP call rather
than one call each, so a full sweep of ~300 cities takes a handful of requests
instead of hundreds.

A refresh **announces itself** over Action Cable, so screens already open don't
sit on stale readings: the globe re-reads its markers when a batch lands (and
when a location is added, renamed or removed), the management index morphs each
batch's rows in as "Refresh all" works through them, and the splash hands over
the moment the refresh it queued finishes rather than waiting out a timer. See
**Live updates** below.

## Live updates

Broadcasts run on [Solid Cable](https://github.com/rails/solid_cable), in
development as well as production — the jobs that broadcast run in their own
process, and the async adapter's pubsub never leaves the process it was
published from. Each environment has its own `cable` database, created by
`bin/rails db:prepare`.

What travels is a **signal, not markup** — unusual for Turbo Streams, and
deliberate. Every weather view converts temperatures and wind through the
visitor's own cookies, and a broadcast renders with no request and no cookies to
read, so streaming rendered HTML would push one visitor's units onto everyone.
Instead the server says "this changed" and each client re-fetches over HTTP,
where its own settings apply again. The two halves are
`app/services/weather_broadcast.rb` and `app/javascript/lib/stream_actions.js`.

The management index takes the same idea through Turbo's own front door — a
page-refresh broadcast, which the browser answers by re-requesting the page and
morphing it in. Morphing is opted into on that view alone, never in the layout:
the Wii screens keep their panel position, header title and 6-hour overlay in
JavaScript, and a morph would stomp all three.

## Jobs

Jobs run on [Solid Queue](https://github.com/rails/solid_queue).

`bin/dev` starts a worker next to the web server; on its own it's:

```bash
bin/jobs
```

[Mission Control — Jobs](https://github.com/rails/mission_control-jobs) serves a
dashboard at **`/jobs`** for queues, workers, and failed jobs (with retry and
discard). It's admin-only, behind the same sign-in as location management.

## Testing

```bash
bin/rails test          # unit + controller + service tests
bin/rails test:system   # system tests (headless Chrome via Selenium)
```

## Deployment

Deploys are [Kamal](https://kamal-deploy.org). `config/deploy.yml` opens with an
ERB line that loads `.env.production.local` itself, so nothing has to be
exported into your shell first — fill the file in and deploy:

```bash
cp .example.env.production.local .env.production.local   # then fill it in
bin/kamal setup    # first time
bin/kamal deploy   # thereafter
```

Everything host-specific is read from that file, which is why the checked-in
`config/deploy.yml` carries no addresses or secrets:

| Variable | Used for |
| --- | --- |
| `SERVER_HOST` | the web server Kamal deploys to |
| `SSH_USERNAME` | the SSH user on it |
| `KAMAL_REGISTRY_IMAGE` | the container image name |
| `PROXY_HOST` | the hostname kamal-proxy serves; also injected into the container, where `production.rb` makes it the only `Host` the app answers to |
| `PROXY_SSL` | `true` to auto-certify with Let's Encrypt |
| `PROXY_HTTP_PORT` / `PROXY_HTTPS_PORT` | the ports kamal-proxy binds |
| `SECRET_KEY_BASE` | injected into the container (`bin/rails secret` generates one) |
| `MAPBOX_TOKEN` | injected into the container, for the globe |

Check what a change renders to before deploying:

```bash
bin/kamal config
```

## Setting sounds

Sign in and upload the four Wii Forecast Channel tracks at `/sounds`, choosing
what each one is:

- **Forecast · Day** / **Forecast · Night** — the forecast screens
- **Globe · Day** / **Globe · Night** — the globe
