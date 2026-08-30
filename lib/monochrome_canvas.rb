# frozen_string_literal: true

# A 1-bit canvas stored in standard BMP bit order: zero is black and one is
# white. It can therefore be returned to the ESP32 without image conversion.
class MonochromeCanvas
  def initialize(width, height)
    @width = width
    @height = height
    @row_bytes = ((width + 31) / 32) * 4
    @pixels = "\xFF".b * (@row_bytes * height)
  end

  def fill_rect(x, y, width, height, black: true)
    x_start = x.round.clamp(0, @width)
    y_start = y.round.clamp(0, @height)
    x_end = (x + width).round.clamp(0, @width)
    y_end = (y + height).round.clamp(0, @height)
    return if x_end <= x_start || y_end <= y_start

    y_start.upto(y_end - 1) do |row|
      x_start.upto(x_end - 1) { |column| set_pixel(column, row, black:) }
    end
  end

  # Ordered patterns create stable light or dark gray impressions on a
  # black-and-white e-paper panel without introducing antialiased pixels.
  def fill_dithered_rect(x, y, width, height, density: :light)
    x_start = x.round.clamp(0, @width)
    y_start = y.round.clamp(0, @height)
    x_end = (x + width).round.clamp(0, @width)
    y_end = (y + height).round.clamp(0, @height)
    return if x_end <= x_start || y_end <= y_start

    y_start.upto(y_end - 1) do |row|
      x_start.upto(x_end - 1) do |column|
        pattern_x = (column - x_start) % 2
        pattern_y = (row - y_start) % 2
        black = case density
                when :dark then !(pattern_x == 1 && pattern_y == 1)
                when :subtle
                  offset_x = column - x_start
                  offset_y = row - y_start
                  (offset_x + offset_y) % 8 == 0 && offset_y.even?
                else pattern_x.zero? && pattern_y.zero?
                end
        set_pixel(column, row, black: true) if black
      end
    end
  end

  def stroke_rect(x, y, width, height)
    horizontal_line(x, x + width - 1, y)
    horizontal_line(x, x + width - 1, y + height - 1)
    vertical_line(x, y, y + height - 1)
    vertical_line(x + width - 1, y, y + height - 1)
  end

  def horizontal_line(x1, x2, y)
    y = y.round
    return unless y.between?(0, @height - 1)

    [x1.round, x2.round].minmax.then do |from, to|
      from.clamp(0, @width - 1).upto(to.clamp(0, @width - 1)) { |x| set_pixel(x, y, black: true) }
    end
  end

  def vertical_line(x, y1, y2)
    x = x.round
    return unless x.between?(0, @width - 1)

    [y1.round, y2.round].minmax.then do |from, to|
      from.clamp(0, @height - 1).upto(to.clamp(0, @height - 1)) { |y| set_pixel(x, y, black: true) }
    end
  end

  def draw_text(x, baseline, text, font:, black: true, anchor: nil)
    x = x.round
    x -= font.text_width(text) / 2 if anchor == :middle
    x -= font.text_width(text) if anchor == :end

    text.each_codepoint do |codepoint|
      glyph = font.glyph_for(codepoint)
      draw_glyph(x + glyph.x_offset, baseline.round - glyph.height - glyph.y_offset, glyph, black:)
      x += glyph.advance
    end
  end

  def bmp
    pixel_data = String.new(encoding: Encoding::BINARY)
    (@height - 1).downto(0) { |row| pixel_data << @pixels.byteslice(row * @row_bytes, @row_bytes) }
    file_size = 62 + pixel_data.bytesize
    header = "BM".b + [file_size, 0, 0, 62].pack("VvvV") +
      [40, @width, @height, 1, 1, 0, pixel_data.bytesize, 0, 0, 2, 0].pack("VllvvVVllVV") +
      "\x00\x00\x00\x00\xFF\xFF\xFF\x00".b
    header + pixel_data
  end

  private

  def draw_glyph(x, y, glyph, black:)
    row_bits = ((glyph.width + 7) / 8) * 8
    glyph.rows.each_with_index do |bits, row|
      glyph.width.times do |column|
        set_pixel(x + column, y + row, black:) if (bits & (1 << (row_bits - column - 1))).positive?
      end
    end
  end

  def set_pixel(x, y, black:)
    return unless x.between?(0, @width - 1) && y.between?(0, @height - 1)

    index = (y * @row_bytes) + (x / 8)
    mask = 0x80 >> (x % 8)
    current = @pixels.getbyte(index)
    @pixels.setbyte(index, black ? current & ~mask : current | mask)
  end
end
