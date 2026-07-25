# Renders the app's two SVG sources into the rasters that browsers and link
# previews ask for:
#
#   icon.svg -> icon.png (512x512, which doubles as the apple-touch-icon)
#               favicon.ico (16/32/48)
#   og.svg   -> og.png (1200x630, the OpenGraph card)
#
# Usage:  ruby script/build_icons.rb
#
# Plain ruby, not `bin/rails runner`: this needs no app, and ruby-vips is a
# system gem rather than a bundled one (image_processing leaves the backend
# optional). The SVGs are the source of truth — edit one, run this, commit the
# rasters alongside it. The .ico is assembled here because vips can't write one;
# its frames are PNGs, which every browser and Windows since Vista reads.

require "vips"

PUBLIC = File.expand_path("../public", __dir__)
ICON = File.join(PUBLIC, "icon.svg")
SOCIAL = File.join(PUBLIC, "og.svg")
PNG_SIZE = 512
ICO_SIZES = [ 16, 32, 48 ].freeze
SOCIAL_SIZE = [ 1200, 630 ].freeze

# Both bounds are maxima and thumbnail keeps the aspect ratio, so a source whose
# viewBox already matches lands exactly on size.
def render(source, width, height = width)
  Vips::Image.thumbnail(source, width, height: height).write_to_buffer(".png")
end

File.binwrite(File.join(PUBLIC, "icon.png"), render(ICON, PNG_SIZE))
File.binwrite(File.join(PUBLIC, "og.png"), render(SOCIAL, *SOCIAL_SIZE))

frames = ICO_SIZES.map { |size| render(ICON, size) }

# ICONDIR: reserved, type (1 = icon), image count.
header = [ 0, 1, frames.size ].pack("v3")

# One ICONDIRENTRY each: width, height, palette size, reserved, colour planes,
# bits per pixel, byte size, and the offset its frame starts at.
offset = header.bytesize + 16 * frames.size
entries = ICO_SIZES.each_with_index.map { |size, i|
  entry = [ size, size, 0, 0, 1, 32, frames[i].bytesize, offset ].pack("C4v2V2")
  offset += frames[i].bytesize
  entry
}.join

File.binwrite(File.join(PUBLIC, "favicon.ico"), header + entries + frames.join)

puts "icon.png #{PNG_SIZE}x#{PNG_SIZE}, favicon.ico #{ICO_SIZES.join('/')}, og.png #{SOCIAL_SIZE.join('x')}"
