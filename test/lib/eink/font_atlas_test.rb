require "test_helper"

class Eink::FontAtlasTest < ActiveSupport::TestCase
  setup { @font = Eink::FontAtlas.fetch }

  test "maps printable ASCII to atlas coordinates" do
    glyphs = @font.glyphs(" A~")

    assert_equal [ [ 0, 0 ], [ 14, 36 ], [ 196, 90 ] ], glyphs.map { |glyph| [ glyph.x, glyph.y ] }
  end

  test "uses the configured fallback for unsupported characters" do
    assert_equal "A?", @font.display_text("Aé")
    assert_equal @font.glyphs("?").first, @font.glyphs("é").first
  end

  test "wraps and fits to complete atlas cells" do
    assert_equal "Silk", @font.fit("Silkscreen", max_width: 64)
    assert_equal [ "one", "two" ], @font.wrap("one two", max_width: 96)
  end
end
