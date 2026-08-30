# frozen_string_literal: true

require "erb"

# Reads the small portion of the BDF format needed by the bundled Terminus
# fonts. A BDF glyph already contains its final black/white pixels, so no font
# rasterizer, anti-aliasing, or thresholding is involved at render time.
class BitmapFont
  Glyph = Data.define(:advance, :width, :height, :x_offset, :y_offset, :rows)

  # Keep the screen's typographic scale on whole 8-pixel units. These BDF
  # files are the exact pixel sizes drawn into the final bitmap.
  FONT_SIZES = [16, 24, 32].freeze
  ROOT = File.expand_path("../assets/fonts/terminus", __dir__)

  def self.for_size(requested_size, bold: false)
    size = FONT_SIZES.min_by { |candidate| [(candidate - requested_size).abs, candidate] }
    @cache ||= {}
    @cache[[size, bold]] ||= new(File.join(ROOT, "ter-u#{size}#{bold ? "b" : "n"}.bdf"))
  end

  attr_reader :ascent, :descent, :pixel_size

  def initialize(path)
    @glyphs = {}
    parse(File.foreach(path, chomp: true))
    @fallback = @glyphs.fetch(0xFFFD, @glyphs.fetch(63))
    @default_advance = @glyphs.fetch(32, @fallback).advance
  end

  def glyph_for(codepoint)
    @glyphs.fetch(codepoint, @fallback)
  end

  def text_width(text)
    text.each_codepoint.sum { |codepoint| glyph_for(codepoint).advance }
  end

  def average_width
    @default_advance
  end

  # Produces browser-renderable, pixel-exact glyphs from the BDF source. SVG is
  # used instead of a browser font so Chromium and the final 1-bit BMP share
  # the exact same glyph metrics and pixels.
  def svg(text, css_class: "bitmap-text")
    return "" if text.empty?

    path = String.new
    x = 0
    text.each_codepoint do |codepoint|
      glyph = glyph_for(codepoint)
      append_svg_path(path, x, glyph)
      x += glyph.advance
    end

    %(<svg class="#{css_class}" xmlns="http://www.w3.org/2000/svg" width="#{x}" height="#{line_height}" viewBox="0 0 #{x} #{line_height}" shape-rendering="crispEdges" aria-label="#{ERB::Util.html_escape(text)}" role="img"><path fill="currentColor" d="#{path}"/></svg>)
  end

  def line_height
    ascent + descent
  end

  private

  def append_svg_path(path, advance, glyph)
    row_bits = ((glyph.width + 7) / 8) * 8
    glyph.rows.each_with_index do |bits, row|
      y = ascent - glyph.height - glyph.y_offset + row
      column = 0
      while column < glyph.width
        unless (bits & (1 << (row_bits - column - 1))).positive?
          column += 1
          next
        end

        run_start = column
        column += 1 while column < glyph.width && (bits & (1 << (row_bits - column - 1))).positive?
        run_width = column - run_start
        path << "M#{advance + glyph.x_offset + run_start} #{y}h#{run_width}v1h-#{run_width}z"
      end
    end
  end

  def parse(lines)
    glyph = nil
    bitmap = false

    lines.each do |line|
      case line
      when /^PIXEL_SIZE (\d+)$/ then @pixel_size = Regexp.last_match(1).to_i
      when /^FONT_ASCENT (\d+)$/ then @ascent = Regexp.last_match(1).to_i
      when /^FONT_DESCENT (\d+)$/ then @descent = Regexp.last_match(1).to_i
      when /^STARTCHAR / then glyph = { rows: [] }
      when /^ENCODING (\d+)$/ then glyph[:codepoint] = Regexp.last_match(1).to_i if glyph
      when /^DWIDTH (-?\d+) / then glyph[:advance] = Regexp.last_match(1).to_i if glyph
      when /^BBX (\d+) (\d+) (-?\d+) (-?\d+)$/
        glyph&.merge!(width: Regexp.last_match(1).to_i, height: Regexp.last_match(2).to_i,
                      x_offset: Regexp.last_match(3).to_i, y_offset: Regexp.last_match(4).to_i)
      when "BITMAP" then bitmap = true
      when "ENDCHAR"
        bitmap = false
        @glyphs[glyph.fetch(:codepoint)] = Glyph.new(
          glyph.fetch(:advance), glyph.fetch(:width), glyph.fetch(:height), glyph.fetch(:x_offset), glyph.fetch(:y_offset), glyph.fetch(:rows)
        )
        glyph = nil
      else
        glyph[:rows] << line.to_i(16) if bitmap && glyph
      end
    end
  end
end
