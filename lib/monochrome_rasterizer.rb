# frozen_string_literal: true

require "base64"
require "open3"
require "ferrum"

# Chromium screenshots the inline bitmap-glyph document; ImageMagick converts
# that one screenshot to the regular, uncompressed 1-bit BMP3 sent to ESP32.
class MonochromeRasterizer
  IMAGE_MAGICK_COMMAND = [ "magick", "png:-",
    "-background", "white",
    "-alpha", "remove",
    "-alpha", "off",
    "-colorspace", "Gray",
    "-threshold", "75%",
    "-type", "bilevel", "-define", "bmp:format=bmp3", "bmp:-"
  ].freeze

  def render(html, width:, height:)
    png = screenshot(html, width:, height:)
    bmp, status = Open3.capture2(*IMAGE_MAGICK_COMMAND, stdin_data: png, binmode: true)
    raise "ImageMagick could not create the calendar BMP" unless status.success?
    raise "ImageMagick returned an unsupported BMP" unless valid_bmp?(bmp, width, height)

    bmp
  end

  private

  def screenshot(html, width:, height:)
    browser = Ferrum::Browser.new(
      window_size: [width, height],
      timeout: 20,
      process_timeout: 20,
      browser_options: {
        "no-sandbox" => nil,
        "disable-dev-shm-usage" => nil,
        "disable-gpu" => nil,
        "disable-font-subpixel-positioning" => nil,
        "disable-lcd-text" => nil,
        "disable-device-discovery-notifications" => nil,
        "force-color-profile" => "srgb"
      }
    )
    browser.go_to("data:text/html;base64,#{Base64.strict_encode64(html)}")
    browser.screenshot(full: true, encoding: :binary)
  ensure
    browser&.quit
  end

  def valid_bmp?(bmp, width, height)
    bmp.start_with?("BM") &&
      bmp.byteslice(10, 4).unpack1("V") == 62 &&
      bmp.byteslice(18, 4).unpack1("V") == width &&
      bmp.byteslice(22, 4).unpack1("V") == height &&
      bmp.byteslice(26, 2).unpack1("v") == 1 &&
      bmp.byteslice(28, 2).unpack1("v") == 1 &&
      bmp.byteslice(30, 4).unpack1("V").zero?
  end
end
