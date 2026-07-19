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
- Build CSS: `npm run build:css`
- Build Javascript: `npm run build`
- Run background worker: `bin/jobs`

## Test Commands

- Headless Chrome via selenium is available running in a separate container on port 45678 under the docker hostname selenium.
- Run all tests: `bin/rails test`
- Run system tests: `bin/rails test:system`
- Run specific test file: `bin/rails test test/path/to/test_file.rb`
- Run specific test method: `bin/rails test test/path/to/test_file.rb:LINE_NUMBER`

## Domain Concepts

- **Location** (`app/models/location.rb`): a place tracked on the globe. Holds
  geocoding data (name, latitude/longitude, country, admin1/region, timezone,
  elevation) plus cached weather. Current conditions and UV are flat columns;
  the today/tomorrow forecasts, 6-hour windows, and 5-day forecast are JSON
  columns. `weather_stale?` gates refresh (1-hour TTL); `refresh_weather!`
  fetches and stores fresh data.
- **WeatherCode** (`app/models/concerns/weather_code.rb`) and **UvIndex**
  (`app/models/concerns/uv_index.rb`): the single sources of truth mapping
  Open-Meteo WMO weather codes and UV values to human labels.
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
  afternoon/evening) for today and tomorrow.
- **WeatherRefresher** (`app/services/weather_refresher.rb`): orchestrates
  fetch → map → `update!` for a Location. Returns false (leaving the record
  untouched) when the fetch fails.
- **Jobs**: `RefreshLocationWeatherJob` refreshes one location;
  `RefreshAllWeatherJob` fans out per-location jobs and is scheduled hourly in
  `config/recurring.yml`. Run the worker with `bin/jobs`.
- **Setting** (`app/models/setting.rb`): a singleton row (`Setting.current`)
  holding app-wide display preferences — `temperature_unit` (celsius/fahrenheit)
  and `wind_unit` (mph/kph). Weather is stored canonically (Celsius, km/h) and
  converted at render time (`display_temperature`, `wind_display`), so switching
  never re-fetches. The "closest location" is separate — a
  `current_location_id` cookie read by `ApplicationController#current_location`.
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
  `/settings/location`): the Wii two-step "choose closest location" screen —
  pick a country, then a location in it (`?country=` toggles the step); striped
  rows on a blue background with a prompt bubble and a scrollable list (`scroller`
  Stimulus controller drives the ▲/▼ bar buttons). `#update` writes the
  `current_location_id` cookie and returns to settings.
- **Locations management UI** (`LocationsController`, `/locations`): CRUD for
  locations. The "New location" page searches by name (Turbo Frame proxy to the
  geocoding client) and pre-fills the form with a picked result's coordinates.
  Rows have a "Refresh" button (synchronous) and the page has "Refresh all"
  (enqueues the bulk job) plus a °C/°F unit toggle (`SettingsController#update`).
  Currently unauthenticated.
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
  halo'd `text-field` to its right. Clicking a marker opens that location's
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
- **Location detail** (`LocationsController#show`): the Wii Forecast
  Channel-style paneled view. Served at the root path `/` for the current
  location (a `current_location_id` cookie later; the first location for now)
  and at `/locations/:id` for a specific one; redirects to add a location when
  none exist. The "Globe" button links to `/map?location=<id>` from your own
  location (centres the globe on it) or plain `/map` from any other location
  (resumes the saved globe view); the music zone follows the same distinction.
  Five full-screen panels — UV Index,
  Current, Today, Tomorrow, 5-Day (default Current) — slide vertically
  (non-looping) via the `forecast` Stimulus controller (arrow buttons + Up/Down
  keys). Panels are partials under `app/views/locations/panels/` wrapped in the
  shared `_frame` chrome; styling is the `.wii-*` block in
  `application.tailwind.css`; the app nav is hidden via `content_for
  :hide_app_nav`. Detailed glossy weather icons come from `WeatherIconsHelper`
  (`weather_icon`, `uv_icon`); `ForecastsHelper` formats temperatures (Wii
  degree style), wind (`compass_direction`/`wind_display`, mph), the "As of"
  timestamp, and weekday abbreviations. Reachable from a globe marker or the
  locations list.
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
  The zone is "globe" on the map, "current" on your own location's forecast,
  and "globe" on any *other* location's forecast — so exploring cities off the
  globe keeps the map track playing, and only returning to your location (e.g.
  the map's "End" button → root) switches back to the "current" track
  (`LocationsController#show` sets `@is_current_location`). Autoplay starts on
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
