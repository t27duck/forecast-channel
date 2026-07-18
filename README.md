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
(The current location comes from a cookie eventually; for now it's the first
location.)

The globe lives at `/map`: a Mapbox satellite globe (stars, atmosphere) that
plots an SVG weather icon and name for each location. Markers are drawn as a
symbol layer, so overlapping ones declutter automatically when zoomed out and
reappear as you zoom in. Click a marker (or a location in the list) to open its
detail view. The globe needs a `mapbox_token` in the Rails credentials:

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

Temperatures are stored in Celsius and displayed in the unit chosen by the °C/°F
toggle on `/locations` (a global preference; no re-fetch needed to switch).

## Testing

```bash
bin/rails test          # unit + controller + service tests
bin/rails test:system   # system tests (headless Chrome via Selenium)
```
