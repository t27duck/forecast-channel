// Inline SVG weather glyphs keyed by condition group. These are rasterized and
// registered as map images (see globe_controller.js); the symbol layer picks
// one per feature via its `icon` property. The WMO code -> group mapping lives
// server-side in app/models/concerns/weather_code.rb (WeatherCode.icon_group).

const CLOUD = '<path d="M7 15h10a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.6 3.6 0 0 0 7 15z" fill="#e8eef7"/>'

// Crescent moon, in a paler gold than the sun; scaled/positioned inline where
// it peeks from behind a cloud (partly_night).
const MOON = '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" fill="#ffe08a"/>'

export const WEATHER_ICONS = {
  clear:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="5" fill="#ffd257"/><g stroke="#ffd257" stroke-width="2" stroke-linecap="round"><line x1="12" y1="1" x2="12" y2="3.5"/><line x1="12" y1="20.5" x2="12" y2="23"/><line x1="1" y1="12" x2="3.5" y2="12"/><line x1="20.5" y1="12" x2="23" y2="12"/><line x1="4" y1="4" x2="5.8" y2="5.8"/><line x1="18.2" y1="18.2" x2="20" y2="20"/><line x1="4" y1="20" x2="5.8" y2="18.2"/><line x1="18.2" y1="5.8" x2="20" y2="4"/></g></svg>',
  clear_night:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">' + MOON + "</svg>",
  partly:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><circle cx="8" cy="8" r="3.6" fill="#ffd257"/>' + CLOUD + "</svg>",
  partly_night:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g transform="translate(1 1) scale(0.5)">' + MOON + "</g>" + CLOUD + "</svg>",
  overcast:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">' + CLOUD + "</svg>",
  fog:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M7 13h10a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.6 3.6 0 0 0 7 13z" fill="#e8eef7"/><g stroke="#cfd8e6" stroke-width="2" stroke-linecap="round"><line x1="5" y1="17" x2="19" y2="17"/><line x1="7" y1="20.5" x2="17" y2="20.5"/></g></svg>',
  rain:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M7 13h10a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.6 3.6 0 0 0 7 13z" fill="#e8eef7"/><g stroke="#7fb2ff" stroke-width="2" stroke-linecap="round"><line x1="8" y1="16" x2="7" y2="20.5"/><line x1="12" y1="16" x2="11" y2="20.5"/><line x1="16" y1="16" x2="15" y2="20.5"/></g></svg>',
  snow:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M7 13h10a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.6 3.6 0 0 0 7 13z" fill="#e8eef7"/><g fill="#d6e6ff"><circle cx="8" cy="18" r="1.4"/><circle cx="12" cy="20" r="1.4"/><circle cx="16" cy="18" r="1.4"/></g></svg>',
  thunder:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M7 13h10a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.6 3.6 0 0 0 7 13z" fill="#e8eef7"/><path d="M12.5 13l-3.5 5h2.4L10.2 22l4-5.2h-2.5l0.8-3.8z" fill="#ffd257"/></svg>',
  unknown:
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="4.5" fill="#94a3b8"/></svg>'
}
