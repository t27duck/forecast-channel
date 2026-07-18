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
  tomorrow forecasts, 6-hour windows, and a 5-day forecast). Fetching live
  weather is handled by a separate, upcoming task; the fields are populated
  then.

## Testing

```bash
bin/rails test          # unit + controller + service tests
bin/rails test:system   # system tests (headless Chrome via Selenium)
```
