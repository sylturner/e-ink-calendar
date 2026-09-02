require "test_helper"

class Eink::ThemeTest < ActiveSupport::TestCase
  test "provides complete typography presets" do
    Eink::Theme::PRESETS.each_value do |preset|
      assert_includes preset.keys, :title_font
      assert_includes preset.keys, :body_font
      assert_includes preset.keys, :footer_font
    end
  end

  test "falls back to Pixelify for an unknown preset" do
    assert_equal Eink::Theme.fetch("pixelify"), Eink::Theme.fetch("missing")
  end
end
