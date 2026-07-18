# README

Forecast is a web-based implementation of the Nintendo Wii's Forecast Channel.

## Getting started

```bash
bundle install
npm install
bin/rails db:migrate
bin/dev            # starts the server plus JS/CSS watchers
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
