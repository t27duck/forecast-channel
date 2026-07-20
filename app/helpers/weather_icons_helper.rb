module WeatherIconsHelper
  # Renders a detailed, glossy weather icon (inline SVG) for a WMO code, in the
  # spirit of the Wii Forecast Channel's artwork. Grouping matches
  # WeatherCode.icon_group; gradient ids are salted per render so multiple icons
  # can share the page without clashing.
  def weather_icon(code, size: 96, classes: "weather-icon")
    group = WeatherCode.icon_group(code)
    salt = SecureRandom.hex(3)

    content_tag :svg, weather_icon_body(group, salt).html_safe,
      viewBox: "0 0 64 64", width: size, height: size, class: classes,
      role: "img", "aria-label": WeatherCode.label_for(code),
      xmlns: "http://www.w3.org/2000/svg"
  end

  # The UV panel's sun-with-sunglasses graphic.
  def uv_icon(size: 96, classes: "uv-icon")
    salt = SecureRandom.hex(3)

    content_tag :svg, uv_icon_body(salt).html_safe,
      viewBox: "0 0 64 64", width: size, height: size, class: classes,
      role: "img", "aria-label": "UV index", xmlns: "http://www.w3.org/2000/svg"
  end

  # The Air Quality panel's breeze graphic.
  def air_quality_icon(size: 96, classes: "aqi-icon")
    salt = SecureRandom.hex(3)

    content_tag :svg, air_quality_icon_body(salt).html_safe,
      viewBox: "0 0 64 64", width: size, height: size, class: classes,
      role: "img", "aria-label": "Air quality", xmlns: "http://www.w3.org/2000/svg"
  end

  # The Laundry Index panel's t-shirt-on-a-line graphic.
  def laundry_icon(size: 96, classes: "laundry-icon")
    salt = SecureRandom.hex(3)

    content_tag :svg, laundry_icon_body(salt).html_safe,
      viewBox: "0 0 64 64", width: size, height: size, class: classes,
      role: "img", "aria-label": "Laundry index", xmlns: "http://www.w3.org/2000/svg"
  end

  private

  def weather_icon_body(group, salt)
    case group
    when "clear" then sun(salt)
    when "partly" then sun(salt, cx: 22, cy: 20, r: 11, rays: :upper) + cloud(salt)
    when "overcast" then cloud(salt, tint: :grey)
    when "fog" then cloud(salt, tint: :grey) + fog_lines
    when "rain" then cloud(salt) + rain_streaks
    when "snow" then cloud(salt) + snowflakes
    when "thunder" then cloud(salt, tint: :storm) + lightning_bolt + rain_streaks(short: true)
    else unknown_mark
    end
  end

  # A glossy sun. `rays: :upper` draws only the top-left rays (for peeking suns).
  def sun(salt, cx: 32, cy: 30, r: 15, rays: :all)
    id = "sun-#{salt}"
    directions = rays == :upper ? [ 180, 225, 270, 315 ] : (0..315).step(45).to_a
    ray_lines = directions.map { |deg|
      rad = deg * Math::PI / 180
      x1 = cx + Math.cos(rad) * (r + 3)
      y1 = cy + Math.sin(rad) * (r + 3)
      x2 = cx + Math.cos(rad) * (r + 9)
      y2 = cy + Math.sin(rad) * (r + 9)
      %(<line x1="#{x1.round(1)}" y1="#{y1.round(1)}" x2="#{x2.round(1)}" y2="#{y2.round(1)}"/>)
    }.join

    <<~SVG
      <defs>
        <radialGradient id="#{id}" cx="42%" cy="38%" r="65%">
          <stop offset="0%" stop-color="#fff3b0"/>
          <stop offset="55%" stop-color="#ffd21e"/>
          <stop offset="100%" stop-color="#ff9d00"/>
        </radialGradient>
      </defs>
      <g stroke="#ffcf3f" stroke-width="3" stroke-linecap="round">#{ray_lines}</g>
      <circle cx="#{cx}" cy="#{cy}" r="#{r}" fill="url(##{id})"/>
      <ellipse cx="#{cx - r * 0.35}" cy="#{cy - r * 0.4}" rx="#{r * 0.4}" ry="#{r * 0.28}" fill="#fff7cf" opacity="0.55"/>
    SVG
  end

  # A fluffy cloud built from overlapping circles with a glossy gradient.
  def cloud(salt, tint: :white)
    id = "cloud-#{salt}"
    top, bottom = case tint
    when :grey then [ "#f2f5fa", "#b9c6da" ]
    when :storm then [ "#dbe2ee", "#93a2ba" ]
    else [ "#ffffff", "#cbd8ea" ]
    end

    <<~SVG
      <defs>
        <linearGradient id="#{id}" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#{top}"/>
          <stop offset="100%" stop-color="#{bottom}"/>
        </linearGradient>
      </defs>
      <g fill="url(##{id})">
        <ellipse cx="30" cy="46" rx="22" ry="6" fill="#0a2a6b" opacity="0.15"/>
        <circle cx="23" cy="40" r="11"/>
        <circle cx="38" cy="35" r="14"/>
        <circle cx="47" cy="41" r="10"/>
        <rect x="19" y="40" width="30" height="11" rx="5.5"/>
      </g>
      <ellipse cx="34" cy="27" rx="8" ry="4" fill="#ffffff" opacity="0.7"/>
    SVG
  end

  def rain_streaks(short: false)
    y2 = short ? 57 : 60
    lines = [ 22, 32, 42 ].map { |x| %(<line x1="#{x}" y1="52" x2="#{x - 3}" y2="#{y2}"/>) }.join
    %(<g stroke="#4aa3ff" stroke-width="3" stroke-linecap="round">#{lines}</g>)
  end

  def snowflakes
    <<~SVG
      <g fill="#d6ecff">
        <circle cx="22" cy="55" r="2.4"/>
        <circle cx="32" cy="59" r="2.4"/>
        <circle cx="42" cy="55" r="2.4"/>
      </g>
    SVG
  end

  def fog_lines
    <<~SVG
      <g stroke="#c3d0e2" stroke-width="3" stroke-linecap="round">
        <line x1="16" y1="55" x2="48" y2="55"/>
        <line x1="21" y1="60" x2="43" y2="60"/>
      </g>
    SVG
  end

  def lightning_bolt
    %(<path d="M34 44 l-8 11 h6 l-3 9 l11 -14 h-6 l4 -6 z" fill="#ffd21e" stroke="#f0a500" stroke-width="0.8"/>)
  end

  def unknown_mark
    <<~SVG
      <circle cx="32" cy="32" r="14" fill="#94a3b8"/>
      <text x="32" y="40" text-anchor="middle" font-size="20" font-weight="700" fill="#fff">?</text>
    SVG
  end

  # Three breeze swirls in a fresh teal→blue, suggesting moving air.
  def air_quality_icon_body(salt)
    id = "aqi-#{salt}"
    <<~SVG
      <defs>
        <linearGradient id="#{id}" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#7fe3d0"/>
          <stop offset="100%" stop-color="#3aa0e6"/>
        </linearGradient>
      </defs>
      <g fill="none" stroke="url(##{id})" stroke-width="4.5" stroke-linecap="round">
        <path d="M12 22 H40 a6 6 0 1 0 -6 -6"/>
        <path d="M12 34 H48 a6.5 6.5 0 1 1 -6.5 6.5"/>
        <path d="M12 46 H34 a5 5 0 1 0 -5 5"/>
      </g>
    SVG
  end

  # A glossy t-shirt hanging on a line.
  def laundry_icon_body(salt)
    id = "shirt-#{salt}"
    <<~SVG
      <defs>
        <linearGradient id="#{id}" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#ffffff"/>
          <stop offset="100%" stop-color="#bcd3ef"/>
        </linearGradient>
      </defs>
      <line x1="6" y1="15" x2="58" y2="15" stroke="#9fb1c9" stroke-width="2"/>
      <path d="M22 17 L13 23 L9 30 L16 35 L22 31 L22 52 L42 52 L42 31 L48 35 L55 30 L51 23 L42 17 C39 22 25 22 22 17 Z"
        fill="url(##{id})" stroke="#8fa8c6" stroke-width="1.5" stroke-linejoin="round"/>
      <path d="M26 17 C28 21 36 21 38 17" fill="none" stroke="#8fa8c6" stroke-width="1.5"/>
      <ellipse cx="30" cy="26" rx="6" ry="3" fill="#ffffff" opacity="0.6"/>
    SVG
  end

  def uv_icon_body(salt)
    id = "uv-#{salt}"
    rays = (0..315).step(45).map { |deg|
      rad = deg * Math::PI / 180
      x1 = 32 + Math.cos(rad) * 17
      y1 = 28 + Math.sin(rad) * 17
      x2 = 32 + Math.cos(rad) * 24
      y2 = 28 + Math.sin(rad) * 24
      %(<line x1="#{x1.round(1)}" y1="#{y1.round(1)}" x2="#{x2.round(1)}" y2="#{y2.round(1)}"/>)
    }.join

    <<~SVG
      <defs>
        <radialGradient id="#{id}" cx="42%" cy="38%" r="65%">
          <stop offset="0%" stop-color="#fffbe6"/>
          <stop offset="60%" stop-color="#ffe14d"/>
          <stop offset="100%" stop-color="#ffb400"/>
        </radialGradient>
      </defs>
      <g stroke="#fff0a0" stroke-width="3" stroke-linecap="round">#{rays}</g>
      <circle cx="32" cy="28" r="15" fill="url(##{id})"/>
      <g fill="#10151c">
        <rect x="19" y="26" width="12" height="9" rx="3"/>
        <rect x="33" y="26" width="12" height="9" rx="3"/>
        <rect x="30" y="28" width="4" height="2.4"/>
      </g>
      <g fill="#ffffff" opacity="0.65">
        <rect x="21" y="28" width="4" height="2.4" rx="1"/>
        <rect x="35" y="28" width="4" height="2.4" rx="1"/>
      </g>
    SVG
  end
end
