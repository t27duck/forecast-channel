## Overview

Forecast is a web-based implementation of the Nintendo Wii's Forecast Channel:
a Wii-style paneled forecast per location, plus a Mapbox globe showing every
location's current conditions.

## Technology Stack

- Ruby 4.0, Rails 8.1, SQLite, Propshaft, Tailwind CSS, Active Storage
- **Background jobs**: Solid Queue in **development** as well as production —
  not the async adapter, so an enqueued job survives a restart and shows up in
  the dashboard. Development mirrors production's layout with a second `queue`
  database (`storage/development_queue.sqlite3`); `bin/dev` runs a worker
  alongside the server.
- **Caching / WebSockets**: Solid Cache, Solid Cable. Cable runs on
  **solid_cable in development too**, with its own `cable` database
  (`storage/development_cable.sqlite3`) — same reason as the queue: the jobs
  that broadcast run in a separate process, and the async adapter's pubsub
  never leaves the process that published it. There is no `app/channels/`;
  `connection_class` defaults to `ActionCable::Connection::Base` and
  `Turbo::StreamsChannel` is the only channel used. See **Live updates**.
- **JavaScript**: esbuild + Node 24, Stimulus, minified. Every top-level file
  in `app/javascript` is an entry point, and there are **two**:
  `application.js` for the app and `globe.js` for the map page alone. The split
  exists because mapbox-gl is ~90% of the weight and only the globe wants it,
  so every other page loads ~40KB gzipped instead of ~560KB. `globe.js`
  registers the globe controller against `window.Stimulus` (so `maps/show` must
  include it *after* the main bundle), which is why `controllers/index.js`
  deliberately doesn't — a `stimulus:manifest:update` puts it back and quietly
  undoes the split, so `test/javascript_bundles_test.rb` guards it. esbuild's
  `--splitting` is **not** usable here: it emits chunk imports whose filenames
  Propshaft digests without rewriting the specifiers, so every chunk 404s in
  production.
- **Secrets**: dotenv, environment-scoped only (`.env.<environment>.local`;
  there is deliberately no plain `.env`, so production values never leak into
  development or test). There are **no** Rails credentials — no
  `config/credentials.yml.enc`, no `master.key`.
- **Deployment**: Kamal. `config/deploy.yml` opens with an ERB line that
  `Dotenv.load`s `.env.production.local`, so server, SSH user, registry image,
  proxy host/ports and the container values all come from that one gitignored
  file — nothing needs exporting into the shell. `SECRET_KEY_BASE` and
  `MAPBOX_TOKEN` go through `env.secret` + `.kamal/secrets` (read after that
  ERB runs), not `env.clear`, which keeps them in a `0600` env file on the host
  rather than on the `docker run` command line. `PROXY_HOST` is injected too,
  under `env.clear` since a hostname isn't a secret: `production.rb` sets
  `config.hosts` from it, so the app answers only to the name it's served
  under (blank leaves the list empty, i.e. unrestricted, so a half-configured
  deploy degrades rather than 403s). `/up` is excluded, because kamal-proxy
  health-checks the container directly and that request doesn't carry
  `PROXY_HOST`. Note `.dockerignore` excludes `/.env*`, so the file itself is
  never in the image — anything the app needs at runtime has to be injected.
- **Authentication**: Rails auth generator with bcrypt
- **External APIs**: [Mapbox](https://docs.mapbox.com/mapbox-gl-js/api/) for
  the globe; [Open-Meteo](https://open-meteo.com/en/docs) (and its
  [geocoding API](https://open-meteo.com/en/docs/geocoding-api)) for weather

## Build Commands

- Start development server: `bin/dev` (Foreman with `Procfile.dev`)
- Start Rails only: `bin/rails server`
- Install dependencies: `bundle install` and `npm install`
- Seed major world cities: `bin/rails db:seed` (idempotent; see `db/seeds.rb`)
- Build CSS: `npm run build:css` — Build JavaScript: `npm run build`
- Run background worker: `bin/jobs` (also started by `bin/dev`)

## Test Commands

- Run all tests: `bin/rails test` — system tests: `bin/rails test:system`
- One file: `bin/rails test test/path/to/file.rb`; one test: append `:LINE`
- Headless Chrome via Selenium runs in a separate container, port 45678, docker
  hostname `selenium`.
- System tests need no secrets: the globe renders offline (see **Globe**), so
  `bin/rails test:system` passes on a fresh checkout with no env file at all.
- Every visitor screen is gated on having chosen a closest location, so a system
  test that visits one starts with `choose_location(locations(:berlin))`
  (`ApplicationSystemTestCase`) — the cookie is signed and httponly, so a real
  browser can only get it by going through the picker.
- The **test cable adapter records broadcasts instead of delivering them**, so a
  system test's browser receives nothing over the socket. Assert the server half
  with `Turbo::Broadcastable::TestHelper` (required by name in
  `test/test_helper.rb`); cover the client half by handing the page the element
  the server would have sent — `Turbo.renderStreamMessage("<turbo-stream …>")`,
  as `test/system/globe_test.rb` and `splash_test.rb` do. That exercises
  everything but the socket itself. A `turbo-cable-stream-source` has no box, so
  `assert_selector` needs `visible: :all`.
- **Never let a system test play a real music track.** A browser streaming one
  of the multi-MB files holds that connection — and one of the test server's
  few threads — open for the whole track; after about four page loads nothing
  else can be served and Turbo navigations hang at random. That's why
  `test/fixtures/files/track.mp3` is 58 bytes and no system test attaches a
  `Sound`.

## Domain Concepts

### Data and weather

- **Location** (`app/models/location.rb`): a place tracked on the globe —
  geocoding data plus cached weather (current conditions, UV, air quality,
  feels-like, humidity and precipitation as flat columns; today/tomorrow,
  the 6-hour windows and the 5-day forecast as JSON columns). See
  `db/schema.rb` for the full set. `weather_stale?` gates refresh (1-hour TTL)
  and `refresh_weather!` fetches and stores fresh weather, plus air quality
  best-effort.
  Addressed in URLs by **slug**, not id (`to_param`;
  `resources :locations, param: :slug`, so controllers use
  `find_by!(slug: params[:slug])` and a numeric id 404s). The slug is
  `[name, admin1, country]` parameterized and joined with `-`
  ("berlin-berlin-germany"), rebuilt by a `before_validation` whenever those
  parts change — so renaming a location changes its URL — and a slug another
  row already holds gains a `-2`/`-3` suffix (unique index). Ids stay internal:
  the `current_location_id` cookie, the refresh jobs and `dom_id` still use
  them.
- **Index concerns**: `WeatherCode` and `UvIndex`
  (`app/models/concerns/`) are the single source of truth mapping Open-Meteo
  WMO codes and UV values to human labels. `WeatherCode.icon_group` also picks
  the marker icon name — distinguishing drizzle, rain, `heavy_rain`, `sleet`,
  snow, `heavy_snow`, thunder and `hail` — and, passed `is_day: false`, returns
  the `_night` variant for clear/partly skies. Those names are shared by the
  flat globe glyphs (`app/javascript/lib/weather_icons.js`) and the glossy
  detail icons (`WeatherIconsHelper`). `AirQuality` maps a US AQI to its EPA
  category (`label_for`) and colour key (`key_for`); `LaundryIndex.rating`
  derives how well washing will dry from the stored conditions (warm + dry +
  breezy + rain-free) as a `Rating` struct, or nil when temperature/humidity
  are missing — a high rain chance is decisive.
- **SolarPosition** (`app/services/solar_position.rb`): whether the sun is
  above the horizon at a coordinate and instant (`day?`), from a low-precision
  solar position — no timezone needed. Drives the globe's day/night icons.
- **Open-Meteo clients** (`app/services/open_meteo/`): `Request` is the shared
  `Net::HTTP` JSON GET helper, failure-tolerant (`nil` on non-success or any
  network/parse error). `GeocodingClient` looks up places by name.
  `ForecastClient` + `WeatherMapper` fetch current/hourly/daily data
  (`timezone=auto`, Celsius) and shape it into Location attributes, bucketing
  hourly data into the four 6-hour windows (overnight/morning/afternoon/
  evening) for today and tomorrow; the mapper is pure. `AirQualityClient` +
  `AirQualityMapper` do the same for US AQI and PM2.5 from the *separate*
  air-quality API. None need a key.
- **Refreshers** (`app/services/`): `WeatherRefresher` and
  `AirQualityRefresher` each orchestrate fetch → map → `update!` for their own
  API. Both return false / skip a chunk, leaving records untouched, when the
  fetch fails. Callers run both: `RefreshWeatherBatchJob` and
  `Location#refresh_weather!`, where air quality never fails the weather
  refresh.
- **Jobs and refresh tiers**: weather is fetched in **batches**, not one
  request per location. `WeatherRefresher.call_many` slices locations into
  `BATCH_SIZE` (50) chunks for `ForecastClient.fetch_many`, which sends
  comma-separated coordinates and gets back an array of payloads *in the same
  order*. The array has no per-location key, so a length guard fails a chunk
  closed rather than risk mispairing. `RefreshWeatherBatchJob` refreshes one
  chunk by ids (so deleted locations drop out), weather **and** air quality;
  `RefreshWeatherTierJob` enqueues the chunks for a tier. `config/recurring.yml`
  runs the **hot** tier hourly and the **cold** tier every 6 hours —
  `Location.hot` is the top `HOT_CITY_COUNT` by population plus anything viewed
  within `RECENTLY_VIEWED_WITHIN` (`last_viewed_at`, stamped by
  `mark_viewed!`), `Location.cold` the remainder. `RefreshAllWeatherJob` backs
  the "Refresh all" button; `RefreshLocationWeatherJob` does a single location
  (enqueued by the splash). Both **broadcast when they're done** — see **Live
  updates**. Recurring tasks are declared for production only, so a development
  worker never fires an hourly refresh at Open-Meteo on its own.
- **Live updates** (`app/services/weather_broadcast.rb` +
  `app/javascript/lib/stream_actions.js`): what goes over the wire is a
  **signal, never rendered HTML** — the one thing Turbo Streams are usually for.
  It has to be: every weather view renders through `current_setting`, which
  reads the visitor's own signed unit cookies, and a broadcast renders outside
  any request with no cookies to read, so streaming markup would push the
  server's defaults onto every listener and quietly break the °C/°F toggle. So
  the server says "this changed" and the client re-fetches over HTTP, where its
  cookies apply again. The transport is `turbo_stream_from` plus **custom
  `Turbo.StreamActions`**, which means no `app/channels/`, no `consumer.js` and
  no new npm dependency (`application.js` already imports `@hotwired/turbo-rails`,
  which registers `<turbo-cable-stream-source>`), and the signed stream names
  keep the unauthenticated `/map` and `/` subscriptions honest. Each action
  dispatches a `CustomEvent` on `window` rather than calling a controller,
  because `globe.js` is a separate bundle and neither bundle can import from the
  other. Three streams:
  - `Location::WEATHER_STREAM` — one for everyone, watched by the globe.
    Broadcast by `RefreshWeatherBatchJob` when a chunk actually wrote something,
    and by `LocationsController`'s create/update/destroy, since the feed carries
    each location's name, slug and coordinates as well as its weather. That's in
    the controller rather than an `after_commit` because `db/seeds.rb` builds
    its ~300 cities through the model and a callback would announce every one.
  - `Location#weather_stream` — per location, slug-keyed like the URLs,
    broadcast by `RefreshLocationWeatherJob`; the splash waits on it.
  - `Location#forecast_stream` — per location too, and **separate from
    `weather_stream` on purpose**: what goes out here is a page refresh, and the
    splash listens on that one, so sharing would refresh the loading screen out
    from under itself. Broadcast per refreshed location rather than once per
    chunk, so a forecast screen only re-requests its page when the place it's
    showing actually moved.
  - `Location::INDEX_STREAM` — the management index, which gets a **Turbo page
    refresh** (`broadcast_refresh_to`) rather than a custom signal. Same
    constraint, different tool: the rows show temperatures in the reader's own
    unit, so the client re-requests the page and Turbo morphs it in. It has to
    be its own stream — a page refresh sent to `WEATHER_STREAM` would tear down
    and rebuild the globe's whole Mapbox instance. Morphing is opted into by
    `content_for :head` on that view alone (`turbo-refresh-method`/`-scroll`),
    never in the layout: the Wii screens keep panel position, the header title
    and the 6-hour overlay in JavaScript. The forecast view opts in too, but
    only alongside the fences described under **Location detail**.
- **Seed data** (`db/seeds.rb`): ~300 major world cities (at least three per US
  state) so the globe is full and the picker's state step isn't sparse.
  Geocoding data was captured once from the Open-Meteo API and baked in
  statically, so `bin/rails db:seed` needs no network; it's idempotent (upsert
  by `open_meteo_id`). Add more with `script/fetch_seed_cities.rb`. Weather is
  filled in afterwards by `RefreshAllWeatherJob`.

### Session and access

- **Authentication** (`Authentication` concern, `SessionsController`, `User`/
  `Session`/`Current`): the Rails 8 auth generator, customised for a **single
  admin** who signs in by `username` (not email). The concern is included in
  `ApplicationController` and adds a global `require_authentication`, so the app
  is **fail-closed**: every action needs a session unless it opts out with
  `allow_unauthenticated_access`. Only `LocationsController`'s management
  actions and `SoundsController` stay protected — `LocationsController#show`,
  `HomeController` (the root), `MapsController`, `SettingsController`,
  `Settings::LocationsController`, `CurrentLocationsController` and
  `SessionsController` (`new`/`create`) all opt out. Sign-in is at
  `/session/new`; there's no password-reset flow. Integration tests use the
  `sign_in_as` cookie helper (`test/test_helpers/`); system tests sign in
  through the form via `ApplicationSystemTestCase`.
- **Visitor cookies** (`ApplicationController#store_visitor_cookie`): the one
  way anything a visitor chose is written — `current_location_id`,
  `temperature_unit`, `wind_unit`. All three are **signed** (a tampered value
  is rejected), **httponly** and **permanent**, the same shape as the
  `session_id` cookie in `Authentication#start_new_session_for`. Reads go
  through `cookies.signed[...]`, so an unsigned value simply doesn't verify and
  the app falls back to its default. In tests, `write_signed_cookie` /
  `read_signed_cookie` / `forget_cookie`
  (`test/test_helpers/cookie_test_helper.rb`) sign and verify through a
  throwaway request's jar, since Rack::Test's own jar has no `#signed` (and
  drops a symbol name).
- **Current location** (`CurrentLocation` concern,
  `app/controllers/concerns/current_location.rb`): reads the
  `current_location_id` cookie with **no fallback** — "hasn't chosen one yet" is
  a real state — and exposes it as a `helper_method`. `require_current_location`
  redirects to the picker until they have; it's declared as a `before_action` on
  exactly the visitor screens (`LocationsController#show`, `MapsController#show`,
  `SettingsController#show`) rather than being fail-closed like authentication,
  so admin CRUD and the `/jobs` engine — which also inherit
  `ApplicationController` — are never asked for a location. **`HomeController`
  is deliberately not on that list**: the splash is what every arrival lands on,
  a shared link's preview included, so it plays for everyone and hands over to
  the picker itself (see **Splash**).
  `store_current_location` writes the cookie and then the regional units below,
  so both ways of choosing (the picker and geolocation) behave the same.
- **Setting** (`app/models/setting.rb`): a plain value object, **not** a DB
  record, holding a visitor's `temperature_unit` and `wind_unit`. Both live in
  the cookies above, so each visitor keeps their own.
  `ApplicationController#current_setting` builds it (unknown/missing units fall
  back to celsius/mph) and exposes it as a `helper_method`;
  `SettingsController#update` writes the cookies, guarded by
  `Setting::TEMPERATURE_UNITS`/`WIND_UNITS`. Weather is stored canonically
  (Celsius, km/h) and converted at render time, so switching never re-fetches.
  `Setting::REGIONAL_UNITS` (via `Setting.units_for`) maps a country code to the
  units that country actually uses — Fahrenheit for `US`/`LR`/`KY`, mph for
  `US`/`GB` — which `store_current_location` seeds for anyone who hasn't set
  that unit themselves. Only differences from the defaults are listed, so
  choosing anywhere else writes nothing.
- **Jobs dashboard** (`/jobs`): [Mission Control — Jobs](https://github.com/rails/mission_control-jobs),
  mounted in `config/routes.rb`. Its controllers inherit the class named in
  `config/initializers/mission_control_jobs.rb` — `ApplicationController` —
  so the dashboard is admin-only through the app's own fail-closed sign-in and
  the gem's HTTP basic auth is switched off. Because the engine has its own
  route set, `Authentication#request_authentication` redirects with
  `main_app.new_session_path`; a bare `new_session_path` raises inside the
  engine.

### Screens

- **Splash** (`HomeController#show` at `/`): the Forecast Channel's loading
  screen — "One moment, please…" over six `weather_icon(0)` suns with a bright
  pulse sweeping left to right (`.splash` in `application.tailwind.css`; the
  cycle is exactly 6 × the per-sun stagger so the loop wraps seamlessly, and
  `prefers-reduced-motion` stills it). The `splash` Stimulus controller holds
  for `MIN_MS`, then `Turbo.visit`s the forecast with `action: "replace"` so the
  screen never enters history; a click or key press skips ahead **and** doubles
  as the gesture the jukebox needs to start playing.
  - It carries **no `require_current_location`**, so it's the one visitor screen
    that renders without a chosen location — a first-time visitor and a link
    preview both get it. With no location the view points
    `data-splash-url-value` at the picker instead of a forecast, and the same
    beat plays before handing over. `@refresh` is therefore an explicit
    `false`, never `nil`: Stimulus reads any value but `"0"`/`"false"` as true,
    so a blank attribute would send a location-less splash off to refresh
    weather it hasn't got.
  - The pause does real work: when the current location's weather is stale the
    view sets `data-splash-refresh-value` **and subscribes to that location's
    stream**, and the controller fetches **the same URL as JSON**, where `#show`
    enqueues `RefreshLocationWeatherJob` and answers immediately. The screen
    then waits for the job's broadcast, so it hands over on a real completion
    signal rather than a timer. Deliberately not synchronous: an Open-Meteo
    round trip inside the request parked one of the server's few threads for its
    whole duration. `weather_stale?` still gates the work, and the **job checks
    it again** — it can't be the rate limit on its own once the answer stops
    waiting for the work. The job calls `refresh_weather!` (not `WeatherRefresher`
    alone) so air quality still comes along, and broadcasts whether or not the
    fetch succeeded, since the screen is waiting to stop waiting. `MAX_MS`
    remains the backstop if the signal is somehow missed.
  - The globe's "End" and settings' "Back" therefore point at
    `location_path(current_location)`, **not** `root_path` — coming back from
    another screen isn't an arrival and shouldn't replay the splash. The admin
    nav's "Forecast" link does still go to `/`.
- **Location detail** (`LocationsController#show` at `/locations/:slug`): the
  Wii Forecast Channel-style paneled view. Seven full-screen panels — three `.wii-index` panels (Laundry, Air Quality,
  UV) then Current, Today, Tomorrow, 5-Day — slide vertically, non-looping,
  via the `forecast` Stimulus controller (arrow buttons + Up/Down keys). Panels
  are partials under `app/views/locations/panels/` wrapped in the shared
  `_frame` chrome; their order, titles and the default are one list
  (`ForecastsHelper::PANELS` / `DEFAULT_PANEL`), which `show` also uses to
  render the track **already scrolled** to the default panel
  (`panel_track_style`) — so the first paint is Current with no JavaScript and
  no flash of the panels above. `WeatherIconsHelper` draws the glossy icons;
  `ForecastsHelper` formats temperatures, wind, local times, the feels-like
  range and the "As of" timestamp. Current/Today/Tomorrow close with a shared
  `_stats` strip (blank stats are dropped). Clicking Today/Tomorrow opens the
  **6-hour overlay** — the day's four windows (from `hourly_windows`) over the
  dimmed forecast, closed by Escape or another click (`sixhour` controller,
  `_six_hour` partial). Styling is the `.wii-*` block in
  `application.tailwind.css`, and the app nav is hidden via
  `content_for :hide_app_nav`.
  - **Live**: the screen subscribes to its location's `forecast_stream` and
    **morphs** a refresh in, so a channel left on doesn't drift hours stale. The
    morph is fenced rather than reacted to: `.wii-top`, `.wii-header` and
    `.wii-bottom` carry `data-forecast-frozen`, and the `forecast` controller
    cancels `turbo:before-morph-element` for them — a cancelled answer skips
    that element and its whole subtree. They're fenced because everything
    JavaScript writes over the server's markup lives in them: the panel title
    (or the weekday the overlay swapped in), the ▲/▼ labels, and the mute icon's
    `is-muted`, which would otherwise say the music was back on while it stayed
    off. That leaves the panels and the "As of" stamp to update, and only two
    things to re-assert on `turbo:morph`: the track's transform (`forecast`
    controller — `#position`, deliberately split from `#chrome` so it can't
    overwrite a weekday title) and the overlay's `is-open` (`sixhour`, which
    tracks `opened` itself rather than reading the class back). Each panel and
    6-hour zone carries an `id` so the morph matches elements instead of
    guessing — the `_stats` strip drops blank tiles, so two renders of a panel
    can differ in shape.
  - **Not `data-turbo-permanent`**, which is the neighbouring idea and the wrong
    one. That marks an element as surviving *navigations*: Turbo matches it by
    `id` and keeps the **old** copy, so the header would strand the previous
    city's name when you walk from one forecast to another (system test:
    "walking to another forecast still re-renders the frozen chrome"). It also
    can't work without an `id`, which Hotwire Dev Tools warns about in the
    console — a test asserts no `[data-turbo-permanent]:not([id])` renders. The
    jukebox is the app's only genuine permanent element, and it has one.
  - The silver bar markup (`.wii-top`/`.wii-bottom`
  plus three `.wii-bar__slot`s) is **shared** — settings and the picker use
  `.wii-bottom` too, with a thin modifier each, so a slot-width "Back" button
  lines up with "GitHub"/"Globe" here. Bars outside `.wii` work because
  `--chrome` is defined on `:root`. The "Globe" button links to `/map?location=<slug>` from your own location and
  plain `/map` from any other; the music zone follows the same distinction.
  The bottom-left slot is an external "GitHub" link to the repository, opened
  in a new tab so the jukebox isn't cut off. It replaced the "Locations" link,
  so **no visitor-facing screen links to `/locations`** — every one of them
  hides the app nav, and an admin now reaches management by URL or from
  another admin page.
- **Globe** (`MapsController#show` at `/map`): a full-bleed Mapbox globe
  (`SATELLITE_STYLE`, `projection: globe`, custom fog + star field) driven by
  the `globe` Stimulus controller, which reaches the page through its own
  bundle (`app/javascript/globe.js`, included via the layout's
  `yield :javascript` — deliberately without `data-turbo-track`, which would
  make Turbo full-reload both entering and leaving the map). The page hides the
  app nav (`content_for :hide_app_nav`).
  - **Offline**: with no Mapbox token the controller builds the same globe on
    `OFFLINE_STYLE` — a valid empty style plus `testMode` — so everything of
    ours renders and nothing is fetched. `MapsHelper#mapbox_token` reads
    `ENV["MAPBOX_TOKEN"]` (dotenv loads it from `.env.development.local`; Kamal
    injects it in production), treating blank as none, and `test/test_helper.rb`
    clears the variable so the suite always takes the offline path even on a
    machine that has a token.
  - **Markers**: served as GeoJSON from `MapsController#markers`
    (`/map/markers`, built by `LocationGeojson`) and drawn as a single **symbol
    layer**, so Mapbox's native collision (`icon/text-allow-overlap: false`)
    declutters when zoomed out and reveals more on zoom-in, with `population`
    as the priority (`symbol-sort-key`). Building the feed walks every
    location, so the controller **caches the serialized JSON** — keyed on
    `Location.all.cache_key` (one COUNT/MAX(updated_at) query, so a new
    location or any weather refresh mints a new key) plus a
    `MARKERS_FRESH_FOR` time bucket, which the day/night icons need because
    `SolarPosition` turns over with the clock and nothing else. It also selects
    only `LocationGeojson::COLUMNS`, keeping `five_day_forecast` and
    `hourly_windows` — JSON columns Active Record parses on access — out of the
    query entirely. The controller rasterizes the SVG
    glyphs in `app/javascript/lib/weather_icons.js` via `map.addImage`. The
    Current-view icon follows each city's local day/night via
    `SolarPosition.day?` (Today/Tomorrow always use the day icon). Hovering
    shows a `.globe-popup` card built from extra `LocationGeojson` properties
    (Celsius; the controller converts using
    `data-globe-temperature-unit-value`). Clicking opens
    `/locations/${slug}` — **hand-built in the controller**, so `to_param`
    doesn't reach it and both sides have to change together.
  - **Controls**: Wii-style top and bottom bars overlaid on the globe (faint at
    20%, 80% on hover) with zoom, pitch, "Restore", "End", and a "Next" button
    cycling the marker icons Current → Today → Tomorrow (`WEATHER_MODES`;
    `#applyMode` swaps the symbol layer's `icon-image` between the
    `icon`/`icon_today`/`icon_tomorrow` properties, which fall back to the
    current icon when that day isn't fetched). A `.map-banner` names the active
    view. Zoom and pitch buttons disable and blank at their limits.
  - **Camera**: `?location=<slug>` exposes `data-globe-center-value` so the
    globe opens centred there. Otherwise the controller restores the
    center/zoom/pitch/bearing it saved to `sessionStorage` (`globeCamera`) on
    `moveend`. So arriving from your own location centres on it, while arriving
    from another location resumes where you left the map. With neither — a first
    visit straight to `/map` — it opens on `DEFAULT_CENTER`, New York at the
    coordinates `db/seeds.rb` gives it, since `DEFAULT_ZOOM` is close enough in
    that a nominal world centre would just be open ocean.
  - **Live**: the page subscribes to `Location::WEATHER_STREAM`, because a globe
    built to be left running would otherwise sit forever on the markers it
    fetched when it opened. On the signal the controller re-points the source at
    the feed — `setData` with the URL plus the broadcast's `version`, which
    defeats a conditional GET returning the bytes the refresh just invalidated —
    and drops any open popup, which holds a snapshot. Debounced by
    `REFETCH_DEBOUNCE`, since a sweep announces itself once per `BATCH_SIZE`
    chunk. Only the source's data changes, so the camera and the active
    Current/Today/Tomorrow view both survive.
  - **Idle**: two seconds without **pointer** movement — or the pointer leaving
    the page, which skips the wait — puts `is-idle` on `.map-view`; the CSS
    slides both bars away, fades the banner and hides the cursor. `pointermove`
    rather than `mousemove` because a finger produces no mouse movement: the
    only other wake event a touch device fires is `pointerdown`, which arrives
    once at the start of a pan and not again, so the chrome would slide away and
    the spin start *mid-drag*, easing the globe west against the finger. Idling
    at
    `SPIN_MAX_ZOOM` also sets the globe turning westward, one revolution per
    `SECONDS_PER_REVOLUTION`, as chained one-second `easeTo`s queued from
    `moveend`; while it drifts the camera isn't saved and waking `map.stop()`s
    it. Too zoomed in, the spin stays armed. `prefers-reduced-motion` skips it.
    **In system tests a bar that has slid away can't be clicked — move the
    pointer first** (`wake_chrome` in `test/system/globe_test.rb`).
  - **Tour**: the bottom bar's "Tour" button (▶/■, one button carrying its own
    state like the jukebox's mute icon) flies the globe city to city — the
    attract mode for the zoom it actually opens at, where the idle spin
    deliberately does nothing. The itinerary is `MapsController`'s
    `Location.most_populous(TOUR_STOP_COUNT)` **sorted by longitude**, which is
    what walks the tour eastward around the world instead of criss-crossing it;
    it joins the route at the first stop east of the current view. Each stop is
    a `flyTo` then its weather card for `TOUR_DWELL_MS`, chained from `moveend`
    — the same seam as the spin, so `#saveCamera` stays out of the way and only
    where the tour was *stopped* is remembered. Two consequences worth knowing:
    `#startSpin` has to yield to a running tour (arming the spin would capture
    that `moveend` branch and strand it), and the `flyTo` is deliberately **not**
    `essential`, so Mapbox jumps rather than swoops for a visitor who asked for
    reduced motion — every stop and card, no animation.
    - The stops carry only slug and coordinates
      (`MapsHelper#tour_stops_value`): coordinates because a city on the far
      side of the globe is in no loaded tile, and the slug so the card is read
      from the marker feed on arrival and shows what the last refresh wrote.
      That lookup is our own `fetch`, **not** `querySourceFeatures` — what
      Mapbox has parsed into source tiles depends on the style's glyphs having
      loaded, which the token-less offline style never does, so that lookup
      finds nothing on a globe with no Mapbox account behind it (and in the
      whole test suite).
    - Unlike the spin, a tour was asked for, so mouse movement doesn't end it —
      it only brings the chrome back, or Stop could never be reached without
      ending the tour on the way. Escape, a gesture on the globe (told apart
      from the tour's own camera moves by Mapbox's `originalEvent`) or any of
      the camera buttons hand control back. "Next" doesn't: it changes what the
      markers show, not where the globe looks, and the card follows it.
- **Settings** (`SettingsController#show` at `/settings`): a Wii-style "Change
  Settings" page with Closest Location, Temperature Display, Wind Display and
  Sound rows. Temp/wind are toggles handled by `#update` (which also backs the
  °C/°F toggle on the locations index, and so is **not** gated on having a
  location); Closest Location opens the picker. Sound is the odd one out — a
  client-side toggle sharing the mute button's `localStorage` rather than a
  cookie (see **Background music**), so it never reaches `#update` at all.
  Reached from the detail view's top-right "Settings" link.
- **Location picker** (`Settings::LocationsController#show` at
  `/settings/location`): the Wii "choose closest location" screen — pick a
  country, then a location in it (`?country=` toggles the step). A country with
  more than `STATE_STEP_THRESHOLD` locations spread across several regions (the
  US today) gets an intermediate `?state=` step so the final city list isn't an
  overwhelming scroll. `#update` stores the location (cookie plus regional
  units) and returns to settings. The `scroller` Stimulus controller drives the
  ▲/▼ buttons. This is also where **first-time setup** happens, so the country
  step pins the geolocation row below and drops the "Back" link — until a
  location exists there is nothing behind it.
- **Geolocation** (`CurrentLocationsController#create` at `/current_location`):
  the picker's green "Use My Current Location" row
  (`settings/locations/_use_current_location`) posts browser coordinates, and
  the controller stores the nearest known location (`Location.nearest_to`,
  Haversine) and returns to settings. The `geolocate` Stimulus controller keeps
  the row hidden until it knows the browser can locate, shows "Locating…" while
  the prompt is up, and on refusal writes an inline `.picker__notice` rather
  than a flash (the layout's flash strip would push these `100vh` screens down).
  Needs a secure origin (HTTPS/localhost) — browsers block geolocation
  otherwise. `test/system/geolocation_test.rb` **stubs
  `navigator.geolocation`** rather than relying on that: whether the test
  server is a secure origin depends on how the suite is driven (`served_by
  host: "rails-app"` isn't; Capybara's default `127.0.0.1`, which CI uses,
  is), so leaving it to the browser makes the test pass here and behave
  differently on GitHub Actions. Stubbing also gives the happy path its only
  end-to-end coverage.
- **Locations management** (`LocationsController`, `/locations`): CRUD, signed
  in only. "New location" searches by name (Turbo Frame proxy to the geocoding
  client) and pre-fills the form with the picked result's coordinates. Rows have
  a synchronous "Refresh"; the page has "Refresh all" (enqueues the bulk job), a
  °C/°F toggle and "Sign out". Because "Refresh all" fans out into a chunk per
  `BATCH_SIZE` and leaves only an optimistic flash behind, the index subscribes
  to `Location::INDEX_STREAM` and **morphs** each batch's rows in as they land
  — see **Live updates** for why it's a page refresh rather than streamed rows,
  and why the morph opt-in is scoped to this view.

### Media and assets

- **Background music** (`jukebox` Stimulus controller): a
  `data-turbo-permanent` player in the layout keeps music going across Turbo
  navigations. It picks a track from the zone (`<body data-music-zone>`, set via
  `content_for :music_zone`) and the time of day (day 7am–7pm, night
  otherwise), flipping at those boundaries; because it only reloads the source
  when that source *changes*, staying in one zone across navigations never
  interrupts playback. Autoplay starts on the first user gesture (tracks use
  `preload="none"`).
  - Zones are **opt-in**: "globe" on the map, "current" on every forecast page,
    and anything that names no zone — the splash, settings, the picker, the
    admin screens — is **silent**, which the layout's default (`"silent"`) makes
    the safe case for any new page. `#trackSrc` returns null there and `refresh`
    *pauses* rather than clearing the source, so the track keeps its position
    and returning to a musical screen resumes mid-track instead of starting
    over. A zone whose track was never uploaded is silent the same way, rather
    than letting the previous screen's music run on. The gesture listener goes
    through `refresh` too, so a click on a silent screen starts nothing.
  - Muting lives in `localStorage` (`jukeboxMuted`) and has two UIs sharing that
    one store, both the `mute` controller talking to the jukebox through an
    outlet: the icon button in the detail view's top bar, and the Sound row on
    the settings page. It is deliberately *not* a visitor cookie like the units
    — muting has to take effect mid-track, and those cookies are httponly, so
    JavaScript couldn't write one anyway.
- **Sound** (`app/models/sound.rb`, `SoundsController` at `/sounds`): an
  uploaded track, one per `kind` (`current_day`/`current_night`/`globe_day`/
  `globe_night` — what the jukebox picks between), with the MP3 in Active
  Storage (`has_one_attached :audio`; non-MP3 rejected). `/sounds` is the
  signed-in-only CRUD screen. The layout asks `SoundsHelper#music_track_paths`
  for each kind's URL; a kind with no upload renders blank, which the controller
  treats as "no track" (the app runs fine with none). Those are
  `rails_storage_proxy_path` URLs — the proxy streams with Range support and
  caches forever, and the path comes from the blob's stable signed id, so it
  doesn't change between pages and playback never restarts on a Turbo
  navigation.
- **App icon and social card**: two SVGs are the source of truth, and
  `ruby script/build_icons.rb` re-renders every raster from them. It's plain
  ruby, not `bin/rails runner`, because ruby-vips is a system gem rather than a
  bundled one; the rasters are committed, so it's a manual step.
  - `public/icon.svg` — the glossy sun-behind-cloud `WeatherIconsHelper` draws
    for "partly cloudy" on a `#103a86` tile, with fatter rays so they survive at
    16px → `public/icon.png` (512, also the apple-touch-icon) and
    `public/favicon.ico` (16/32/48). All four `<link rel="icon">` tags live in
    the layout.
  - `public/og.svg` — the same mark full-bleed beside a wordmark →
    `public/og.png` (1200×630), the OpenGraph card. The wordmark is live
    `<text>`, so it sets in whatever sans-serif the machine running the script
    has; **look at the result before committing it** rather than assuming, and
    leave the right-hand margin generous because a substituted font sets wider
    and an overflowing line is clipped, not wrapped.
- **Link previews** (`app/views/layouts/_open_graph.html.erb`, rendered from the
  layout's head): `og:*`, `twitter:card` and a plain `meta description`.
  Deliberately **one card for the whole site**, not per-page — every visitor
  screen but the splash is gated on `require_current_location` and a crawler
  carries no cookie, so `/` is the only public page a preview ever reaches, and
  per-location tags would be markup nothing reads. Absolute URLs come from
  `request.base_url` (there's no `default_url_options` outside Action Mailer;
  `config.assume_ssl` makes it `https://` in production), and `og:url` uses
  `request.path` so a query string doesn't fragment the canonical URL.
- **Cursors**: the Wii hand cursors in `app/assets/images/cursors/`, wired up as
  `--cursor-point` / `--cursor-open-hand` / `--cursor-grab` (with hotspots) at
  the top of `application.tailwind.css`. The CSS points at the `-32` (32×32)
  downscales, **not** the full-size art beside them: Chromium refuses a bigger
  custom cursor the moment it would spill outside the page, which brought the OS
  arrow back over the button bars at the screen edges. Regenerate with
  `Vips::Image.thumbnail(src, 32, height: 32)` if the art changes. The pointing
  hand is the cursor for the whole app; the globe canvas shows the open hand,
  closing to the fist while dragged (`is-pointing` / `is-grabbing` on
  `.map-view`).
- **Mobile viewport**: the five full-screen views (`.wii`, `.settings`,
  `.picker`, `.splash`, `.map-canvas`) are fixed frames, not documents, so they
  each carry `height: 100vh` **followed by `100dvh`** — the pair, not one or the
  other, since the first is the fallback. `dvh` is safe precisely because
  nothing in them scrolls: the URL bar never retracts, so the value never moves.
  Everything *else* stays on `vh` on purpose — `--chrome` and the dozens of
  `clamp(…vh…)` sizes would otherwise reflow type and resize bars as a browser
  animated its chrome. The layout asks for `viewport-fit=cover`, without which
  `env(safe-area-inset-*)` is reported as 0; `:root` names the four insets as
  `--safe-*`, and each bar grows by its own inset and pads that much away, so
  the silver runs under the status bar and home indicator while the buttons stay
  a full `--chrome` tall. `overscroll-behavior: none` is set on `html` (only the
  root propagates it to the viewport), scoped by `:has()` so the admin CRUD
  screens keep ordinary scrolling; `.picker__list`, the one thing that does
  scroll, contains its own. `.wii` takes `touch-action: pinch-zoom` — claiming
  the vertical gesture for the swipe controller while deliberately *keeping*
  zoom, which `none` would remove from a screen sized entirely in `clamp()`s.
  The globe's bars get `@media (hover: none) { opacity: 0.8 }`, since their
  `:hover` rule never fires on a phone and the whole control surface would
  otherwise sit at a fifth opacity forever.

## Instructions

- Write code in the "Rails Way" and take advantage of the framework and
  best-practice design patterns.
- Always read entire files. Otherwise you don't know what you don't know, and
  will duplicate code that already exists or misunderstand the architecture.
- Organise code into separate files wherever appropriate, and follow general
  coding best practices about naming, modularity, function complexity, file
  sizes and comments.
- Code is read more often than it is written; optimise for readability.
- Do not carry out large refactors unless explicitly instructed to.
- For UI and UX work, follow best practices and pay attention to interaction
  patterns and micro-interactions — be proactive about smooth, engaging
  interfaces.

## Documentation Maintenance

Keep `CLAUDE.md` and `README.md` updated as the project evolves: when adding or
removing significant dependencies, changing the stack or infrastructure, adding
domain concepts or models, restructuring directories, adding build/test/deploy
commands, or changing authentication or API patterns. Include the documentation
update in the same commit or PR.
