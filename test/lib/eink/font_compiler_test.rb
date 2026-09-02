require "test_helper"

class Eink::FontCompilerTest < ActiveSupport::TestCase
  test "ships a reproducible Silkscreen source font and binary atlas" do
    font = Eink::FontCompiler::FONTS.fetch(0)
    compiler = Eink::FontCompiler.new(font)
    manifest = JSON.parse(Rails.root.join("config/eink_fonts/#{font.key}.json").read)

    assert_equal "silkscreen-regular-16", manifest.fetch("key")
    assert_equal "vendor/eink_fonts/silkscreen/Silkscreen-Regular.ttf", manifest.fetch("source")
    assert_equal Digest::SHA256.file(font.source).hexdigest, manifest.fetch("source_sha256")
    assert_equal 32, manifest.dig("range", "first")
    assert_equal 126, manifest.dig("range", "last")
    assert_equal [ 16, 16 ], manifest.fetch("cell").values_at("width", "height")

    compiler.validate!
  end

  test "compiles a fresh 1-bit atlas from the vendored font file" do
    font = Eink::FontCompiler::FONTS.fetch(0)

    Dir.mktmpdir("eink-font-test") do |directory|
      compiler = Eink::FontCompiler.new(font, output_root: directory)
      compiler.compile!

      atlas = Vips::Image.new_from_file(File.join(directory, "app/assets/images/eink_fonts/#{font.key}.png"))
      published_atlas = Vips::Image.new_from_file(Rails.root.join("app/assets/images/eink_fonts/#{font.key}.png").to_s)
      manifest = JSON.parse(File.read(File.join(directory, "config/eink_fonts/#{font.key}.json")))

      assert_equal [ 256, 96 ], [ atlas.width, atlas.height ]
      assert_equal [ 0, 255 ], atlas.write_to_memory.bytes.uniq.sort
      assert_equal published_atlas.write_to_memory, atlas.write_to_memory
      assert_equal "app/assets/images/eink_fonts/silkscreen-regular-16.png", manifest.dig("atlas", "path")
    end
  end
end
