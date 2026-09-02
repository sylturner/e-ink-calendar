require "vips"

module Eink
  class BmpRenderer
    WIDTH = 800
    HEIGHT = 480
    CELL_WIDTH = WIDTH / Dashboard::GRID_COLUMNS
    CELL_HEIGHT = HEIGHT / Dashboard::GRID_ROWS
    ROW_BYTES = WIDTH / 8
    PIXEL_BYTES = ROW_BYTES * HEIGHT
    FILE_HEADER_BYTES = 62

    def initialize(dashboard)
      @dashboard = dashboard
    end

    def render
      monochrome_bmp(pixel_rows(canvas))
    end

    private

    attr_reader :dashboard

    def canvas
      dashboard.dashboard_items.enabled.order(:grid_y, :grid_x).reduce(white_canvas) do |image, item|
        draw_panel(image, item, ComponentRegistry.build(item).cached_panel)
      end
    end

    def white_canvas
      (Vips::Image.black(WIDTH, HEIGHT) + 255).cast(:uchar)
    end

    def draw_panel(image, item, panel)
      x = (item.grid_x * CELL_WIDTH) + 6
      y = (item.grid_y * CELL_HEIGHT) + 6
      width = (item.grid_width * CELL_WIDTH) - 12
      height = (item.grid_height * CELL_HEIGHT) - 12
      image = image.draw_rect([ 0 ], x, y, width, height, fill: false)
      image = image.draw_rect([ 0 ], x + 8, y + 29, width - 16, 1, fill: true)
      image = draw_text(image, panel.title, x + 10, y + 8, size: 15)

      max_lines = [ (height - 44) / 16, 1 ].max
      panel.lines.flat_map { |line| wrap(line, width) }.first(max_lines).each_with_index do |line, index|
        image = draw_text(image, line, x + 10, y + 35 + (index * 16), size: 13)
      end

      draw_text(image, panel.footer, x + 10, y + height - 20, size: 11) if panel.footer.present?
      image
    end

    def draw_text(image, value, x, y, size:)
      text = Vips::Image.text(value.to_s, font: "DejaVu Sans #{size}").invert
      image.insert(text, x, y)
    end

    def wrap(line, width)
      limit = [ (width - 20) / 7, 12 ].max
      line.to_s.scan(/.{1,#{limit}}(?:\s+|\z)/).map(&:strip).reject(&:blank?).presence || [ line.to_s.truncate(limit) ]
    end

    def pixel_rows(image)
      pixels = image.write_to_memory
      HEIGHT.times.map do |row|
        ROW_BYTES.times.map do |byte_index|
          8.times.reduce(0) do |byte, bit_index|
            pixel = pixels.getbyte((row * WIDTH) + (byte_index * 8) + bit_index)
            (byte << 1) | (pixel >= 128 ? 1 : 0)
          end
        end.pack("C*")
      end
    end

    def monochrome_bmp(rows)
      file_size = FILE_HEADER_BYTES + PIXEL_BYTES
      file_header = "BM".b + [ file_size, 0, 0, FILE_HEADER_BYTES ].pack("VvvV")
      dib_header = [ 40, WIDTH, HEIGHT, 1, 1, 0, PIXEL_BYTES, 2835, 2835, 2, 0 ].pack("V3v2V6")
      palette = "\x00\x00\x00\x00\xff\xff\xff\x00".b

      file_header + dib_header + palette + rows.reverse.join
    end
  end
end
