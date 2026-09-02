require "test_helper"

class Eink::PixelFontTest < ActiveSupport::TestCase
  test "normalizes unsupported glyphs and uses a fixed character advance" do
    assert_equal "A? 9", Eink::PixelFont.display_text("aé 9")
    assert_equal 12, Eink::PixelFont.advance(2)
    assert_equal 18, Eink::PixelFont.line_height(2)
  end

  test "wraps text to whole words before splitting long words" do
    assert_equal [ "ONE", "TWO" ], Eink::PixelFont.wrap("one two", max_width: 36, scale: 1)
    assert_equal [ "ABC", "DEF" ], Eink::PixelFont.wrap("abcdef", max_width: 18, scale: 1)
  end

  test "draws only black and white pixels" do
    image = Eink::PixelFont.image("A", scale: 2)

    assert_equal [ 12, 14 ], [ image.width, image.height ]
    assert_equal [ 0, 255 ], image.write_to_memory.bytes.uniq.sort
  end

  test "yields the exact pixels used by image rendering" do
    assert_equal 18, Eink::PixelFont.each_pixel("A", scale: 1).count
  end
end
