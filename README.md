# README

Forecast is a web-based implementation of the Nintendo Wii's Forecast Channel.

## Getting started

```bash
bundle install
npm install
bin/rails db:migrate
bin/dev            # starts the server plus JS/CSS watchers
```

## Forecast & globe

The root page (`/`) shows the current location's forecast — a Wii Forecast
Channel-style set of panels (UV, Current, Today, Tomorrow, 5-Day) that slide
vertically; clicking the Today or Tomorrow panel reveals its 6-hour breakdown.
On a first visit the app asks the browser for your location and opens the
nearest one (needs HTTPS or localhost); otherwise it falls back to the first
location. You can also set it explicitly in Settings.

The globe lives at `/map`: a Mapbox satellite globe (stars, atmosphere) that
plots an SVG weather icon and name for each location. Markers are drawn as a
symbol layer, so overlapping ones declutter automatically when zoomed out and
reappear as you zoom in. Click a marker (or a location in the list) to open its
detail view. A Wii-style bar overlaid on the top of the globe holds "Zoom" (out),
"Next", and "Zoom" (in) buttons, and a green banner names what the markers show —
"Next" cycles the icons through Current, Today's, and Tomorrow's weather. The bar
stays faint until you hover it. The globe needs a `mapbox_token` in the Rails
credentials:

```bash
bin/rails credentials:edit   # add: mapbox_token: pk....
```

## Locations

Locations are the places plotted on the globe. Manage them at `/locations`:

- **New location** searches by place name (powered by the free Open-Meteo
  geocoding API — no API key required), captures the latitude/longitude and
  location metadata, and lets you review before saving.
- Each location also stores cached weather (current conditions, UV, today/
  tomorrow forecasts, 6-hour windows, and a 5-day forecast), fetched from the
  free Open-Meteo forecast API.

## Weather refresh

Cached weather is fetched from Open-Meteo and refreshed periodically:

- **Manually**: on `/locations`, use a row's "Refresh" button (immediate) or
  "Refresh all" (enqueues a background job).
- **Automatically**: `RefreshAllWeatherJob` is scheduled hourly via
  `config/recurring.yml`. Run the Solid Queue worker with `bin/jobs` to process
  enqueued and recurring jobs.

## Settings

The `/settings` page (reached from the forecast's "Settings" link) chooses the
closest location (a Wii-style country-then-location picker), the temperature
unit (°C/°F), and the wind unit (mph/kph).
Units are global display preferences — weather is stored canonically (Celsius,
km/h) and converted at render time, so switching never re-fetches. There's also
a quick °C/°F toggle on the `/locations` list.

## Testing

```bash
bin/rails test          # unit + controller + service tests
bin/rails test:system   # system tests (headless Chrome via Selenium)
```

## Background music

Drop the four Wii Forecast Channel tracks into `public/audio/` named:

- `current-day.mp3` / `current-night.mp3` — the forecast screens
- `globe-day.mp3` / `globe-night.mp3` — the globe

The player switches by zone (globe vs forecast) and time of day (day 7am–7pm,
night otherwise), persists across navigations, and starts on the first click.
Until the files are present, the app runs fine with no music.
