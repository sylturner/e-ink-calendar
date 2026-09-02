require "json"

module Eink
  class FontAtlas
    DEFAULT_KEY = "pixelify-sans-20"
    Glyph = Data.define(:codepoint, :x, :y)

    def self.fetch(key = DEFAULT_KEY)
      new(key)
    end

    def initialize(key)
      @manifest = JSON.parse(Rails.root.join("config/eink_fonts/#{key}.json").read)
    end

    def glyphs(value)
      display_text(value).codepoints.map do |codepoint|
        index = codepoint - first_codepoint
        Glyph.new(codepoint, (index % columns) * cell_width, (index / columns) * cell_height)
      end
    end

    def display_text(value)
      value.to_s.codepoints.map { |codepoint| supported?(codepoint) ? codepoint : fallback_codepoint }.pack("U*")
    end

    def fit(value, max_width:)
      display_text(value).first([ max_width / cell_width, 1 ].max)
    end

    def wrap(value, max_width:)
      limit = [ max_width / cell_width, 1 ].max
      display_text(value).split("\n", -1).flat_map { |paragraph| wrap_paragraph(paragraph, limit) }
    end

    def asset_path
      manifest.dig("atlas", "path").delete_prefix("app/assets/images/")
    end

    def atlas_width = columns * cell_width
    def atlas_height = rows * cell_height
    def cell_width = manifest.dig("cell", "width")
    def cell_height = manifest.dig("cell", "height")

    private

    attr_reader :manifest

    def columns = manifest.dig("atlas", "columns")
    def rows = manifest.dig("atlas", "rows")
    def first_codepoint = manifest.dig("range", "first")
    def last_codepoint = manifest.dig("range", "last")
    def fallback_codepoint = manifest.dig("range", "fallback")

    def supported?(codepoint)
      codepoint.between?(first_codepoint, last_codepoint)
    end

    def wrap_paragraph(paragraph, limit)
      return [ "" ] if paragraph.empty?

      paragraph.split(/\s+/).each_with_object([]) do |word, lines|
        word.chars.each_slice(limit).map(&:join).each do |part|
          if lines.empty? || part.length == limit || lines.last.length + 1 + part.length > limit
            lines << part
          else
            lines[-1] = "#{lines.last} #{part}"
          end
        end
      end
    end
  end
end
