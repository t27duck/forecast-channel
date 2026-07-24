# Renders public/icon.svg into the raster favicons browsers ask for:
# icon.png (512x512, which doubles as the apple-touch-icon) and favicon.ico
# (16/32/48).
#
# Usage:  ruby script/build_favicons.rb
#
# Plain ruby, not `bin/rails runner`: this needs no app, and ruby-vips is a
# system gem rather than a bundled one (image_processing leaves the backend
# optional). icon.svg is the source of truth — edit it, run this, commit all
# three. The .ico is assembled here because vips can't write one; its frames are
# PNGs, which every browser and Windows since Vista reads.

require "vips"

PUBLIC = File.expand_path("../public", __dir__)
SOURCE = File.join(PUBLIC, "icon.svg")
PNG_SIZE = 512
ICO_SIZES = [ 16, 32, 48 ].freeze

def render(size)
  Vips::Image.thumbnail(SOURCE, size, height: size).write_to_buffer(".png")
end

File.binwrite(File.join(PUBLIC, "icon.png"), render(PNG_SIZE))

frames = ICO_SIZES.map { |size| render(size) }

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

puts "icon.png #{PNG_SIZE}x#{PNG_SIZE}, favicon.ico #{ICO_SIZES.join('/')}"
