require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

module Eink
  class FontCompiler
    GlyphSet = (32..126).freeze
    Font = Data.define(:key, :source, :point_size, :cell_width, :cell_height, :crop_x, :crop_y, :columns)

    FONTS = [
      Font.new(
        key: "silkscreen-regular-16",
        source: Rails.root.join("vendor/eink_fonts/silkscreen/Silkscreen-Regular.ttf"),
        point_size: 20,
        cell_width: 14,
        cell_height: 16,
        crop_x: 2,
        crop_y: 6,
        columns: 16
      ),
      Font.new(
        key: "pixelify-sans-20",
        source: Rails.root.join("vendor/eink_fonts/pixelify_sans/PixelifySans[wght].ttf"),
        point_size: 20,
        cell_width: 14,
        cell_height: 18,
        crop_x: 1,
        crop_y: 5,
        columns: 16
      ),
      Font.new(
        key: "pixel-operator-8-16",
        source: Rails.root.join("vendor/eink_fonts/pixel_operator/PixelOperator8.ttf"),
        point_size: 16,
        cell_width: 15,
        cell_height: 16,
        crop_x: 2,
        crop_y: 0,
        columns: 16
      ),
      Font.new(
        key: "pixel-operator-8-bold-16",
        source: Rails.root.join("vendor/eink_fonts/pixel_operator/PixelOperator8-Bold.ttf"),
        point_size: 16,
        cell_width: 15,
        cell_height: 16,
        crop_x: 2,
        crop_y: 0,
        columns: 16
      ),
      Font.new(
        key: "vhs-gothic-16",
        source: Rails.root.join("vendor/eink_fonts/vhs_gothic/vhs-gothic.ttf"),
        point_size: 16,
        cell_width: 12,
        cell_height: 16,
        crop_x: 1,
        crop_y: 2,
        columns: 16
      ),
      Font.new(
        key: "upheaval-24",
        source: Rails.root.join("vendor/eink_fonts/upheaval/upheavtt.ttf"),
        point_size: 24,
        cell_width: 16,
        cell_height: 16,
        crop_x: 0,
        crop_y: 5,
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
      character_path = File.join(directory, format("%03d.txt", codepoint))
      File.binwrite(character_path, codepoint.chr)

      run!(
        "magick", "-background", "white", "-fill", "black", "+antialias",
        "-font", font.source.to_s, "-pointsize", font.point_size.to_s, "label:@#{character_path}",
        "-crop", "#{font.cell_width}x#{font.cell_height}+#{font.crop_x}+#{font.crop_y}", "+repage",
        "-gravity", "NorthWest", "-extent", "#{font.cell_width}x#{font.cell_height}",
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
        raster: { point_size: font.point_size, crop_x: font.crop_x, crop_y: font.crop_y },
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
