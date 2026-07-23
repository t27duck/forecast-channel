# README

Forecast is a web-based implementation of the Nintendo Wii's Forecast Channel.

## Getting started

```bash
bundle install
npm install
bin/rails db:migrate
bin/rails db:seed   # populate the globe with ~300 major world cities
bin/dev             # starts the server plus JS/CSS watchers
```

`db:seed` loads a curated set of major world cities (geocoding data baked into
`db/seeds.rb`, so it needs no network) so the globe is populated on a fresh
database. It's idempotent, and only sets each city's location/metadata — their
weather is filled in by the hourly refresh (`bin/jobs`, or "Refresh all" in the
locations UI).

## Forecast & globe

The root page (`/`) shows the current location's forecast — a Wii Forecast
Channel-style set of panels (UV, Air Quality, Laundry Index, Current, Today,
Tomorrow, 5-Day) that slide vertically; clicking the Today or Tomorrow panel
reveals its 6-hour breakdown. Air Quality shows the US AQI and PM2.5; the
Laundry Index rates how well washing will dry from the current conditions. The
Current/Today/Tomorrow panels also carry a stats strip — feels-like temperature,
humidity, rain chance, wind, and sunrise/sunset.
On a first visit the app asks the browser for your location and opens the
nearest one (needs HTTPS or localhost); otherwise it falls back to the first
location. You can also set it explicitly in Settings.

The globe lives at `/map`: a Mapbox satellite globe (stars, atmosphere) that
plots an SVG weather icon and name for each location. Markers are drawn as a
symbol layer, so overlapping ones declutter automatically when zoomed out and
reappear as you zoom in. A city's current-weather marker follows its local time
of day — clear and partly-cloudy skies show a moon after dark instead of a sun.
Point at a marker to preview its weather in a popup, or
click it (or a location in the list) to open the full detail view. A Wii-style bar overlaid on the top of the globe holds "Zoom" (out),
"Next", and "Zoom" (in) buttons, and a green banner names what the markers show —
"Next" cycles the icons through Current, Today's, and Tomorrow's weather. A bottom
bar holds "End" (back to your forecast), two tilt buttons, and "Restore" (reset the
tilt). The bars stay faint until you hover them. Wii hand cursors are used
throughout: a pointing hand everywhere, swapping to an open hand over the globe
and a fist while you drag it. The globe needs a `mapbox_token`
in the Rails credentials:

```bash
bin/rails credentials:edit   # add: mapbox_token: pk....
```

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
  and everywhere else every 6 hours. Run the Solid Queue worker with `bin/jobs`
  to process enqueued and recurring jobs.

Requests are **batched**: up to 50 locations are fetched per HTTP call rather
than one call each, so a full sweep of ~200 cities takes a handful of requests
instead of hundreds. Together with the tiers this cuts daily requests from
roughly 4,900 to ~40, and roughly a third of the API quota.

## Settings

The `/settings` page (reached from the forecast's "Settings" link) chooses the
closest location (a Wii-style country-then-location picker), the temperature
unit (°C/°F), and the wind unit (mph/kph).
Units are per-visitor display preferences stored in the browser (cookies, like
the closest location) — weather is stored canonically (Celsius, km/h) and
converted at render time, so switching never re-fetches and every visitor keeps
their own units. There's also a quick °C/°F toggle on the `/locations` list.

## Testing

```bash
bin/rails test          # unit + controller + service tests
bin/rails test:system   # system tests (headless Chrome via Selenium)
```

## Background music

Sign in and upload the four Wii Forecast Channel tracks at `/sounds`, choosing
what each one is:

- **Forecast · Day** / **Forecast · Night** — the forecast screens
- **Globe · Day** / **Globe · Night** — the globe

The MP3s are stored with Active Storage (so they're uploaded through the app,
not copied onto the server). The player switches by zone (globe vs forecast) and
time of day (day 7am–7pm, night otherwise), persists across navigations, and
starts on the first click. The globe track plays on the map, and every
location's forecast plays the forecast track. Slots you haven't uploaded are
simply silent, and the app runs fine with no sounds at all.
