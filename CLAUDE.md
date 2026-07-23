## Overview

Forecast is a web-based implementation of the Nintendo Wii's Forecast Channel.

## Technology Stack

- Ruby: 4.0
- Rails: 8.1
- Database: SQLite
- Asset Pipeline: Propshaft
- Backgorund Jobs: Solid Queue
- Caching: Solid Cache
- WebSockets: Solid Cable
- Deployment: Kamal
- Javascript: esbuild and Node 24 with Stimulus controllers
- CSS: Tailwind CSS
- File uploads: Active Storage
- Authentication: Rails auth generator with bcrypt
- Maps: Mapbox (Documentation: https://docs.mapbox.com/mapbox-gl-js/api/)
- Weather source: Open-Meteo (Documentation: https://open-meteo.com/en/docs and https://open-meteo.com/en/docs/geocoding-api)

## Build Commands

- Start development server: `bin/dev` (uses Foreman with Procfile.dev)
- Start Rails only: `bin/rails server`
- Install dependencies: `bundle install` and `npm install`
- Seed major world cities: `bin/rails db:seed` (idempotent; see `db/seeds.rb`)
- Build CSS: `npm run build:css`
- Build Javascript: `npm run build`
- Run background worker: `bin/jobs`

## Test Commands

- Headless Chrome via selenium is available running in a separate container on port 45678 under the docker hostname selenium.
- Run all tests: `bin/rails test`
- Run system tests: `bin/rails test:system`
- Run specific test file: `bin/rails test test/path/to/test_file.rb`
- Run specific test method: `bin/rails test test/path/to/test_file.rb:LINE_NUMBER`
- The test environment serves nothing out of `public/`
  (`public_file_server.enabled = false`): a browser streaming one of the
  multi-MB music tracks holds that connection — and one of the test server's few
  threads — open for the whole track, which starved the server and made Turbo
  navigations hang at random. Leave it off unless a test needs a public file.

## Domain Concepts

- **Location** (`app/models/location.rb`): a place tracked on the globe. Holds
  geocoding data (name, latitude/longitude, country, admin1/region, timezone,
  elevation) plus cached weather. Current conditions, UV, air quality
  (`air_quality_index`/`air_quality_label`/`air_quality_pm2_5`), feels-like
  (`current_apparent_temperature`), humidity and precipitation probability are
  flat columns; the today/tomorrow forecasts, 6-hour windows, and 5-day forecast
  are JSON columns (each day also carrying `sunrise`/`sunset` and apparent
  high/low). `weather_stale?` gates
  refresh (1-hour TTL); `refresh_weather!` fetches and stores fresh weather
  (and, best-effort, air quality). `air_quality_name` labels the stored AQI and
  `laundry_rating` derives the laundry index from the current conditions.
- **WeatherCode** (`app/models/concerns/weather_code.rb`) and **UvIndex**
  (`app/models/concerns/uv_index.rb`): the single sources of truth mapping
  Open-Meteo WMO weather codes and UV values to human labels. `icon_group`
  also picks the marker icon name — distinguishing drizzle, rain, `heavy_rain`,
  `sleet` (freezing), snow, `heavy_snow`, thunder and `hail` — and, passed
  `is_day: false`, returns the `_night` variant for clear/partly skies (a sun
  becomes a moon). The names are shared by the flat globe glyphs
  (`app/javascript/lib/weather_icons.js`) and the glossy detail icons
  (`WeatherIconsHelper`).
- **AirQuality** (`app/models/concerns/air_quality.rb`) and **LaundryIndex**
  (`app/models/concerns/laundry_index.rb`): more index concerns. `AirQuality`
  maps a US AQI value to its EPA category (`label_for`) and a colour key
  (`key_for`). `LaundryIndex.rating` derives how well washing will dry from the
  stored current conditions (warm + dry + breezy + rain-free) — a `Rating`
  struct (`key`/`label`/`blurb`), or nil when temperature/humidity are missing;
  a high rain chance is decisive.
- **SolarPosition** (`app/services/solar_position.rb`): computes whether the
  sun is above the horizon at a coordinate and instant (`day?`), from a
  low-precision solar position — no timezone needed. Drives the globe's
  day/night marker icons.
- **OpenMeteo::Request** (`app/services/open_meteo/request.rb`): shared
  `Net::HTTP` JSON GET helper for the Open-Meteo APIs. Failure-tolerant —
  returns `nil` on non-success status or any network/parse error.
- **OpenMeteo::GeocodingClient**: looks up places by name via the geocoding API
  (`https://geocoding-api.open-meteo.com/v1/search`, no API key); returns `[]`
  on blank queries and errors.
- **OpenMeteo::ForecastClient** + **OpenMeteo::WeatherMapper**: the client
  fetches current/hourly/daily data from the forecast API
  (`https://api.open-meteo.com/v1/forecast`, `timezone=auto`, Celsius); the
  mapper (pure, side-effect free) shapes the payload into Location attributes,
  bucketing hourly data into the four 6-hour windows (overnight/morning/
  afternoon/evening) for today and tomorrow. It also carries feels-like
  (apparent) temperature, humidity, precipitation probability, and each day's
  sunrise/sunset.
- **OpenMeteo::AirQualityClient** + **OpenMeteo::AirQualityMapper**: fetch and
  shape current air quality from the *separate* air-quality API
  (`https://air-quality-api.open-meteo.com/v1/air-quality`, no key) — US AQI and
  PM2.5. Same batching contract as the forecast client (comma-separated coords →
  array in order, length-guarded).
- **WeatherRefresher** (`app/services/weather_refresher.rb`) and
  **AirQualityRefresher** (`app/services/air_quality_refresher.rb`): each
  orchestrates fetch → map → `update!` for its own API (weather vs. air quality;
  air quality is a separate endpoint, so a separate pass). Both return false /
  skip a chunk, leaving records untouched, when the fetch fails. Callers run
  both: `RefreshWeatherBatchJob` and `Location#refresh_weather!` (where air
  quality is best-effort and never fails the weather refresh).
- **Jobs / refresh tiers**: weather is fetched in **batches**, not one request
  per location. `WeatherRefresher.call_many` slices locations into
  `BATCH_SIZE` (50) chunks and calls `OpenMeteo::ForecastClient.fetch_many`,
  which sends comma-separated coordinates and gets back an array of payloads in
  the same order (`timezone=auto` still resolves per location). The array has no
  per-location key, so a length guard fails a chunk closed rather than risk
  mispairing. `RefreshWeatherBatchJob` refreshes one chunk (by ids, so deleted
  locations drop out) — weather **and** air quality, via
  `AirQualityRefresher.call_many` (a second batched request to the air-quality
  API); `RefreshWeatherTierJob` enqueues those chunks for a tier.
  `config/recurring.yml` runs the **hot** tier hourly and the **cold** tier every
  6 hours — `Location.hot` is the top `HOT_CITY_COUNT` by population plus
  anything viewed within `RECENTLY_VIEWED_WITHIN` (`last_viewed_at`, stamped by
  `Location#mark_viewed!` from `LocationsController#show`, throttled);
  `Location.cold` is the remainder. `RefreshAllWeatherJob` still refreshes
  everything (the "Refresh all" button) and `RefreshLocationWeatherJob` still
  does a single location. Run the worker with `bin/jobs`.
- **Setting** (`app/models/setting.rb`): a plain value object (not a DB record)
  holding a visitor's display preferences — `temperature_unit`
  (celsius/fahrenheit) and `wind_unit` (mph/kph). Both are **per-visitor**,
  stored in `temperature_unit`/`wind_unit` browser cookies (like the "closest
  location" `current_location_id` cookie) so each visitor keeps their own.
  `ApplicationController#current_setting` builds the object from those cookies
  (unknown/missing units fall back to the defaults celsius/mph) and exposes it
  as a `helper_method`; `SettingsController#update` writes the cookies (guarded
  by `Setting::TEMPERATURE_UNITS`/`WIND_UNITS`). Weather is stored canonically
  (Celsius, km/h) and converted at render time via `current_setting`
  (`display_temperature`, `wind_display`), so switching never re-fetches.
- **Settings screen** (`SettingsController#show` at `/settings`): a Wii-style
  "Change Settings" page with Closest Location, Temperature Display, and Wind
  Display rows (each a "Change" control). Temp/wind are toggles handled by
  `#update` (which also backs the °C/°F toggle on the locations index); Closest
  Location's "Change" opens the picker. Reached from the detail view's top-right
  "Settings" link.
- **Geolocation** (`CurrentLocationsController#create` at `/current_location`):
  on the root path with no location cookie set, `LocationsController#show` marks
  the page `@auto_locate` and renders a hidden form driven by the `geolocate`
  Stimulus controller, which asks the browser for coordinates on load and posts
  them. The controller picks the nearest stored location (`Location.nearest_to`,
  Haversine) into the cookie and redirects to its forecast. Denied/unavailable
  geolocation silently keeps the default. Needs a secure origin
  (HTTPS/localhost) — the browser blocks geolocation otherwise.
- **Location picker** (`Settings::LocationsController#show` at
  `/settings/location`): the Wii "choose closest location" screen — pick a
  country, then a location in it (`?country=` toggles the step). A country with
  more than `STATE_STEP_THRESHOLD` locations spread across several regions (the
  US today) gets an intermediate state/region step (`?state=`) so the final city
  list isn't an overwhelming scroll; smaller countries still list cities
  directly. Striped rows on a blue background with a prompt bubble and a
  scrollable list (`scroller` Stimulus controller drives the ▲/▼ bar buttons).
  `#update` writes the `current_location_id` cookie and returns to settings.
- **Locations management UI** (`LocationsController`, `/locations`): CRUD for
  locations. The "New location" page searches by name (Turbo Frame proxy to the
  geocoding client) and pre-fills the form with a picked result's coordinates.
  Rows have a "Refresh" button (synchronous) and the page has "Refresh all"
  (enqueues the bulk job) plus a °C/°F unit toggle (`SettingsController#update`)
  and a "Sign out" button. These management actions require signing in (see
  Authentication); the forecast/globe/settings views are public.
- **Authentication** (`Authentication` concern, `SessionsController`, `User`/
  `Session`/`Current` models): the Rails 8 auth generator (bcrypt
  `has_secure_password`), customised for a **single admin** who signs in by
  `username` (not email). The concern is included in `ApplicationController`
  and adds a global `require_authentication` before_action, so the app is
  **fail-closed**: every action needs a session unless it opts out with
  `allow_unauthenticated_access`. Only `LocationsController`'s management
  actions stay protected — everything public opts out: `LocationsController`
  for `:show` (the forecast/root), `MapsController`, `SettingsController`,
  `Settings::LocationsController`, `CurrentLocationsController`, and
  `SessionsController` (`new`/`create`). The styled sign-in page lives at
  `/session/new`; there's no password-reset flow (single admin). Sessions are a
  signed, httponly `session_id` cookie. In tests, integration specs use the
  `sign_in_as` cookie helper (`test/test_helpers/`); system specs sign in
  through the form via the helper on `ApplicationSystemTestCase`.
- **Seed data** (`db/seeds.rb`): populates ~300 major world cities (including at
  least three per US state) so the globe is full and the picker's state step
  isn't sparse on a fresh database. The geocoding data (identity/coordinates
  only, no weather) was captured once from the Open-Meteo geocoding API and
  baked in statically, so `bin/rails db:seed` needs no network; it's idempotent
  (upsert by `open_meteo_id`). Add more with `script/fetch_seed_cities.rb`.
  Weather is filled in afterwards by `RefreshAllWeatherJob`.
- **Globe** (`MapsController#show` at `/map`): a full-bleed Mapbox globe
  (`standard-satellite` style, `projection: globe`, custom fog + star field)
  driven by the `globe` Stimulus controller (`app/javascript/controllers/
  globe_controller.js`). Locations are served as GeoJSON from
  `MapsController#markers` (`/map/markers`, built by `LocationGeojson`) and
  drawn as a single **symbol layer** so Mapbox's native collision
  (`icon/text-allow-overlap: false`) declutters overlapping markers when zoomed
  out and reveals more on zoom-in; `population` is the collision priority
  (`symbol-sort-key`). The controller rasterizes the SVG glyphs in
  `app/javascript/lib/weather_icons.js` via `map.addImage`; each feature's
  `icon` (from `WeatherCode.icon_group`) picks one, with the name as a
  halo'd `text-field` to its right. The Current-view icon follows each city's
  local day/night: `LocationGeojson` asks `SolarPosition.day?` and, after dark,
  a clear/partly marker shows a moon (`clear_night`/`partly_night`) instead of a
  sun (Today/Tomorrow always use the day icon). Pointing at a marker shows a hover popup
  (`.globe-popup`, dark Wii card) with that location's weather for the active
  view — temperature/condition + high/low for Current, or high/low + condition
  for Today/Tomorrow — built from extra `LocationGeojson` properties
  (`temp`/`label`/`today_*`/`tomorrow_*`, Celsius; the controller converts using
  `data-globe-temperature-unit-value`). Clicking a marker opens that location's
  detail view. The page hides the app nav (`content_for :hide_app_nav`) and
  the globe fills the viewport; a Wii-style top bar (`.wii-top.map-bar`,
  reusing the detail-view bar styling + `press` animation) is overlaid on the
  globe with three buttons — "Zoom" (circle-minus, out), "Next" (▶, center)
  and "Zoom" (circle-plus, in) — wired to the globe controller's
  `zoomOut`/`next`/`zoomIn` actions. Zoom moves one Mapbox unit and each zoom
  button disables + blanks at its limit (`#syncZoomButtons` on the `zoom`
  event). "Next" cycles the marker icons Current → Today → Tomorrow → Current
  (`WEATHER_MODES`, `#applyMode` swaps the symbol layer's `icon-image` between
  the `icon`/`icon_today`/`icon_tomorrow` feature properties from
  `LocationGeojson`, which fall back to the current icon when that day isn't
  fetched). A green banner below the bar (`.map-banner`, `banner` target) names
  the active view. A matching bottom bar (`.map-bar--bottom`) holds "End" (a
  link back to the root forecast), two curved-arrow tilt buttons
  (`globe#pitchUp`/`globe#pitchDown`, ±`PITCH_STEP`° via `easeTo`, disabling +
  blanking at the pitch limits like the zoom buttons), and "Restore"
  (`globe#resetPitch` back to `DEFAULT_PITCH`). Both bars are faint (20%
  opacity) and rise to 80% on hover. `MapsController#show` accepts a
  `?location=<id>` param and, when present, exposes `data-globe-center-value`
  so the globe opens centred on that location. The globe otherwise resumes the
  view it was last left at: the controller saves center/zoom/pitch/bearing to
  `sessionStorage` (`globeCamera`) on `moveend` and restores it on connect when
  no focus param is given. So arriving from your own location centres on it,
  while arriving from another location (whose "Globe" button omits the param)
  resumes where you left the map.
- **Cursors**: the Wii hand cursors in `app/assets/images/cursors/`, wired up as
  the `--cursor-point` / `--cursor-open-hand` / `--cursor-grab` custom
  properties (with hotspots) at the top of `application.tailwind.css`. The CSS
  points at the `-32` (32x32) downscales, not the full-size art beside them:
  Chromium refuses a bigger custom cursor the moment it would spill outside the
  page, which brought the OS arrow back over the button bars at the screen
  edges. Regenerate them with `Vips::Image.thumbnail(src, 32, height: 32)` if
  the art changes. The
  pointing hand is the cursor for the whole app — including the map's control
  bars and markers — while the globe canvas shows the open hand, closing to the
  fist while it's dragged. The globe controller toggles `is-pointing` (marker
  hover) and `is-grabbing` (Mapbox `dragstart`/`dragend`) on `.map-view`; the
  CSS under "Map control bar" does the rest.
- **Location detail** (`LocationsController#show`): the Wii Forecast
  Channel-style paneled view. Served at the root path `/` for the current
  location (a `current_location_id` cookie later; the first location for now)
  and at `/locations/:id` for a specific one; redirects to add a location when
  none exist. The "Globe" button links to `/map?location=<id>` from your own
  location (centres the globe on it) or plain `/map` from any other location
  (resumes the saved globe view); the music zone follows the same distinction.
  Seven full-screen panels — three "index" panels (UV Index, Air Quality,
  Laundry Index) then Current, Today, Tomorrow, 5-Day (default Current) — slide
  vertically (non-looping) via the `forecast` Stimulus controller (arrow buttons
  + Up/Down keys). The three index panels share the `.wii-index` figure/boxes
  layout; the Laundry panel colours its rating and the Air Quality panel its
  category (`AirQuality.key_for`). Panels are partials under
  `app/views/locations/panels/` wrapped in the shared `_frame` chrome; styling
  is the `.wii-*` block in
  `application.tailwind.css`; the app nav is hidden via `content_for
  :hide_app_nav`. Detailed glossy weather icons come from `WeatherIconsHelper`
  (`weather_icon`, `uv_icon`); `ForecastsHelper` formats temperatures (Wii
  degree style), wind (`compass_direction`/`wind_display`, mph), local times
  (`forecast_time`), the feels-like range (`apparent_range`), the "As of"
  timestamp, and weekday abbreviations. The Current/Today/Tomorrow panels close
  with a shared `_stats` strip (`.wii-stats` tiles) — feels-like, humidity, rain
  chance, wind, and sunrise/sunset (blank stats are dropped). Reachable from a
  globe marker or the locations list.
  - **6-hour overlay:** clicking the Today/Tomorrow panel opens a breakdown of
    the day's four 6-hour windows (overnight/morning/afternoon/evening, from
    `hourly_windows`) over the dimmed forecast, swapping the header title to the
    weekday; Escape or another click closes it (`sixhour` Stimulus controller,
    `six_hour_windows`/`weekday_name` helpers, `_six_hour` partial).

- **Background music** (`jukebox` Stimulus controller): a `data-turbo-permanent`
  player in the layout keeps music going across Turbo navigations. It picks a
  track from the zone (`<body data-music-zone>`, set via `content_for
  :music_zone`) and the time of day (day 7am–7pm, night otherwise), flipping at
  those boundaries; because it only reloads the source when that source
  changes, staying in one zone across navigations never interrupts playback.
  The zone is "globe" on the map and "current" on every forecast page
  (whichever location it shows), so leaving the globe for any location's
  forecast switches to the "current" track. Autoplay starts on
  the first user gesture (tracks use `preload="none"` so the large files only
  download when playback starts). A mute button in the detail view's top-bar
  left slot (`mute` Stimulus controller, connected to the jukebox via an outlet)
  toggles the audio and remembers the choice in `localStorage`. MP3s live in
  `public/audio/`: `current-day.mp3`, `current-night.mp3`, `globe-day.mp3`,
  `globe-night.mp3` (missing files just 404 — no music until added).

## Design

- Weather data cached in the database and refreshed periodically.
- Globe view with locations/cities current forecast icons.
- Globe uses a satilite map preferably using higher contract blues and greens if possible.
- Globe and be zoomed out to show the whole planet with stars in space.
- Detail view: Wii-style paneled forecast per location (built; see Domain Concepts).

## Weather data stored
- Location name and latitude/longitude
- Current conditions: Temperature, condition name, condition icon/image, wind (speed + direction)
- Today's and tomorrow's forecast also include wind (max speed + dominant direction)
- Today's forcast: Temperature, condition name, condition icon/image
- Tommorrow's forcast: Temperature, condition name, condition icon/image
- A breakdown of the today's and tomorrow's forecast for 6 hour windows (overnight, morning, afternoon, and evening hours)
- 5-day forecasts: High temperature, low temperature, and condition icon/image
- Current UV index: Numeric value and label (low, moderate, high, etc.)

## Instructions

- Write code in the "Rails Way" and take advantage of the functionality of the Rails framework and best practice design patterns.
- Always read entire files. Otherwise, you don't know what you don't know, and will end up making mistakes, duplicating code that already exists, or misunderstanding the architecture.
- Organise code into separate files wherever appropriate, and follow general coding best practices about variable naming, modularity, function complexity, file sizes, commenting, etc.
- Code is read more often than it is written, optimize code for readability.
- Do not carry out large refactors unless explicitly instructed to do so.
- When doing UI & UX work, make sure designs are easy to use and follow UI / UX best practices. Pay attention to interaction patterns, micro-interactions, and are proactive about creating smooth, engaging user interfaces that delight users.

## Documentation Maintenance

Keep `CLAUDE.md` and `README.md` updated as the project evolves. Update these files when:

- Adding or removing significant dependencies (gems, JS libraries)
- Changing the technology stack or infrastructure
- Adding new domain concepts or models
- Restructuring directories or namespaces
- Adding new build, test, or deployment commands
- Changing authentication, authorization, or API patterns

When making such changes, include documentation updates in the same commit or PR.
