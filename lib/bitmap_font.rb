# frozen_string_literal: true

# Reads the small portion of the BDF format needed by the bundled Terminus
# fonts. A BDF glyph already contains its final black/white pixels, so no font
# rasterizer, anti-aliasing, or thresholding is involved at render time.
class BitmapFont
  Glyph = Data.define(:advance, :width, :height, :x_offset, :y_offset, :rows)

  FONT_SIZES = [12, 14, 16, 18, 20, 24, 28, 32].freeze
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

  private

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
