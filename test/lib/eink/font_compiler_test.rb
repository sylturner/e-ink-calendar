require "test_helper"

class Eink::FontCompilerTest < ActiveSupport::TestCase
  test "ships a reproducible Pixelify Sans source font and binary atlas" do
    font = Eink::FontCompiler::FONTS.find { |configured_font| configured_font.key == "pixelify-sans-20" }
    compiler = Eink::FontCompiler.new(font)
    manifest = JSON.parse(Rails.root.join("config/eink_fonts/#{font.key}.json").read)

    assert_equal "pixelify-sans-20", manifest.fetch("key")
    assert_equal "vendor/eink_fonts/pixelify_sans/PixelifySans[wght].ttf", manifest.fetch("source")
    assert_equal Digest::SHA256.file(font.source).hexdigest, manifest.fetch("source_sha256")
    assert_equal 32, manifest.dig("range", "first")
    assert_equal 126, manifest.dig("range", "last")
    assert_equal 20, manifest.dig("raster", "point_size")
    assert_equal [ 1, 5 ], manifest.fetch("raster").values_at("crop_x", "crop_y")
    assert_equal [ 14, 18 ], manifest.fetch("cell").values_at("width", "height")

    compiler.validate!

    atlas = Vips::Image.new_from_file(Rails.root.join(manifest.dig("atlas", "path")).to_s)
    title_glyph = Eink::FontAtlas.fetch.glyphs("T").first
    title_glyph_pixels = atlas.extract_area(title_glyph.x, title_glyph.y, 14, 18).write_to_memory.bytes

    assert_operator title_glyph_pixels.count(0), :>, 40
  end

  test "compiles a fresh 1-bit atlas from the vendored font file" do
    font = Eink::FontCompiler::FONTS.find { |configured_font| configured_font.key == "pixelify-sans-20" }

    Dir.mktmpdir("eink-font-test") do |directory|
      compiler = Eink::FontCompiler.new(font, output_root: directory)
      compiler.compile!

      atlas = Vips::Image.new_from_file(File.join(directory, "app/assets/images/eink_fonts/#{font.key}.png"))
      published_atlas = Vips::Image.new_from_file(Rails.root.join("app/assets/images/eink_fonts/#{font.key}.png").to_s)
      manifest = JSON.parse(File.read(File.join(directory, "config/eink_fonts/#{font.key}.json")))

      assert_equal [ 224, 108 ], [ atlas.width, atlas.height ]
      assert_equal [ 0, 255 ], atlas.write_to_memory.bytes.uniq.sort
      assert_equal published_atlas.write_to_memory, atlas.write_to_memory
      assert_equal "app/assets/images/eink_fonts/pixelify-sans-20.png", manifest.dig("atlas", "path")
    end
  end
end
