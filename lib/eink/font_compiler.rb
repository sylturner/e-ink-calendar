require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

module Eink
  class FontCompiler
    GlyphSet = (32..126).freeze
    Font = Data.define(:key, :source, :point_size, :cell_width, :cell_height, :columns)

    FONTS = [
      Font.new(
        key: "silkscreen-regular-16",
        source: Rails.root.join("vendor/eink_fonts/silkscreen/Silkscreen-Regular.ttf"),
        point_size: 32,
        cell_width: 16,
        cell_height: 16,
        columns: 16
      )
    ].freeze

    def self.compile_all!
      FONTS.each { |font| new(font).compile! }
    end

    def initialize(font, output_root: Rails.root)
      @font = font
      @output_root = Pathname(output_root)
    end

    def compile!
      raise "ImageMagick's magick command is required to compile E Ink fonts" unless magick_available?
      raise "Font file not found: #{font.source}" unless font.source.exist?

      Dir.mktmpdir("eink-font") do |directory|
        glyph_paths = GlyphSet.map { |codepoint| render_glyph!(directory, codepoint) }
        compile_atlas!(directory, glyph_paths)
      end

      write_manifest!
      validate!
    end

    def validate!
      image = Vips::Image.new_from_file(atlas_path.to_s).flatten(background: [ 255 ]).cast(:uchar)
      values = image.write_to_memory.bytes.uniq.sort

      raise "Glyph atlas must be strictly black and white, got #{values.inspect}" unless values.all? { |value| [ 0, 255 ].include?(value) }
      raise "Unexpected atlas dimensions" unless [ image.width, image.height ] == [ font.columns * font.cell_width, rows * font.cell_height ]
      raise "Missing font manifest" unless manifest_path.exist?
    end

    private

    attr_reader :font, :output_root

    def render_glyph!(directory, codepoint)
      path = File.join(directory, format("%03d.png", codepoint))
      run!(
        "magick", "-size", "#{font.cell_width}x#{font.cell_height}", "xc:white",
        "+antialias", "-font", font.source.to_s, "-pointsize", font.point_size.to_s,
        "-fill", "black", "-gravity", "NorthWest", "-annotate", "+0+0", codepoint.chr,
        "-type", "bilevel", path
      )
      path
    end

    def compile_atlas!(directory, glyph_paths)
      FileUtils.mkdir_p(atlas_path.dirname)
      blank_path = File.join(directory, "blank.png")
      run!("magick", "-size", "#{font.cell_width}x#{font.cell_height}", "xc:white", blank_path)

      row_paths = glyph_paths.each_slice(font.columns).with_index.map do |glyph_row, index|
        padded_row = glyph_row + Array.new(font.columns - glyph_row.size, blank_path)
        row_path = File.join(directory, format("row-%02d.png", index))
        run!("magick", *padded_row, "+append", row_path)
        row_path
      end

      run!("magick", *row_paths, "-append", "-type", "bilevel", atlas_path.to_s)
    end

    def write_manifest!
      FileUtils.mkdir_p(manifest_path.dirname)
      manifest_path.write(JSON.pretty_generate(
        key: font.key,
        source: font.source.relative_path_from(Rails.root).to_s,
        source_sha256: Digest::SHA256.file(font.source).hexdigest,
        range: { first: GlyphSet.begin, last: GlyphSet.end, fallback: "?".ord },
        cell: { width: font.cell_width, height: font.cell_height },
        atlas: { path: atlas_path.relative_path_from(output_root).to_s, columns: font.columns, rows: }
      ) + "\n")
    end

    def atlas_path
      output_root.join("app/assets/images/eink_fonts/#{font.key}.png")
    end

    def manifest_path
      output_root.join("config/eink_fonts/#{font.key}.json")
    end

    def rows
      (GlyphSet.size.to_f / font.columns).ceil
    end

    def magick_available?
      system("magick", "-version", out: File::NULL, err: File::NULL)
    end

    def run!(*command)
      _output, error, status = Open3.capture3(*command)
      raise "Font compiler failed: #{error.presence || command.join(" ")}" unless status.success?
    end
  end
end
