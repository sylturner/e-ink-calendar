module Eink
  # A deliberately small, fixed-grid display font. Keeping the glyphs as pixels
  # means the BMP never has to threshold anti-aliased vector text.
  module PixelFont
    GLYPHS = {
      " " => %w[00000 00000 00000 00000 00000 00000 00000],
      "!" => %w[00100 00100 00100 00100 00100 00000 00100],
      '"' => %w[01010 01010 01010 00000 00000 00000 00000],
      "#" => %w[01010 11111 01010 01010 11111 01010 01010],
      "$" => %w[00100 01111 10100 01110 00101 11110 00100],
      "%" => %w[11001 11010 00100 01000 10110 00110 00000],
      "&" => %w[01100 10010 10100 01000 10101 10010 01101],
      "'" => %w[00100 00100 01000 00000 00000 00000 00000],
      "(" => %w[00010 00100 01000 01000 01000 00100 00010],
      ")" => %w[01000 00100 00010 00010 00010 00100 01000],
      "*" => %w[00000 10101 01110 11111 01110 10101 00000],
      "+" => %w[00000 00100 00100 11111 00100 00100 00000],
      "," => %w[00000 00000 00000 00000 00100 00100 01000],
      "-" => %w[00000 00000 00000 11111 00000 00000 00000],
      "." => %w[00000 00000 00000 00000 00000 00110 00110],
      "/" => %w[00001 00010 00100 01000 10000 00000 00000],
      "0" => %w[01110 10001 10011 10101 11001 10001 01110],
      "1" => %w[00100 01100 00100 00100 00100 00100 01110],
      "2" => %w[01110 10001 00001 00010 00100 01000 11111],
      "3" => %w[11110 00001 00001 01110 00001 00001 11110],
      "4" => %w[00010 00110 01010 10010 11111 00010 00010],
      "5" => %w[11111 10000 10000 11110 00001 00001 11110],
      "6" => %w[01110 10000 10000 11110 10001 10001 01110],
      "7" => %w[11111 00001 00010 00100 01000 01000 01000],
      "8" => %w[01110 10001 10001 01110 10001 10001 01110],
      "9" => %w[01110 10001 10001 01111 00001 00001 01110],
      ":" => %w[00000 00110 00110 00000 00110 00110 00000],
      ";" => %w[00000 00110 00110 00000 00110 00100 01000],
      "<" => %w[00010 00100 01000 10000 01000 00100 00010],
      "=" => %w[00000 11111 00000 11111 00000 00000 00000],
      ">" => %w[01000 00100 00010 00001 00010 00100 01000],
      "?" => %w[01110 10001 00001 00010 00100 00000 00100],
      "@" => %w[01110 10001 10111 10101 10111 10000 01110],
      "A" => %w[01110 10001 10001 11111 10001 10001 10001],
      "B" => %w[11110 10001 10001 11110 10001 10001 11110],
      "C" => %w[01110 10001 10000 10000 10000 10001 01110],
      "D" => %w[11110 10001 10001 10001 10001 10001 11110],
      "E" => %w[11111 10000 10000 11110 10000 10000 11111],
      "F" => %w[11111 10000 10000 11110 10000 10000 10000],
      "G" => %w[01110 10001 10000 10111 10001 10001 01110],
      "H" => %w[10001 10001 10001 11111 10001 10001 10001],
      "I" => %w[01110 00100 00100 00100 00100 00100 01110],
      "J" => %w[00001 00001 00001 00001 10001 10001 01110],
      "K" => %w[10001 10010 10100 11000 10100 10010 10001],
      "L" => %w[10000 10000 10000 10000 10000 10000 11111],
      "M" => %w[10001 11011 10101 10101 10001 10001 10001],
      "N" => %w[10001 11001 10101 10011 10001 10001 10001],
      "O" => %w[01110 10001 10001 10001 10001 10001 01110],
      "P" => %w[11110 10001 10001 11110 10000 10000 10000],
      "Q" => %w[01110 10001 10001 10001 10101 10010 01101],
      "R" => %w[11110 10001 10001 11110 10100 10010 10001],
      "S" => %w[01111 10000 10000 01110 00001 00001 11110],
      "T" => %w[11111 00100 00100 00100 00100 00100 00100],
      "U" => %w[10001 10001 10001 10001 10001 10001 01110],
      "V" => %w[10001 10001 10001 10001 10001 01010 00100],
      "W" => %w[10001 10001 10001 10101 10101 10101 01010],
      "X" => %w[10001 10001 01010 00100 01010 10001 10001],
      "Y" => %w[10001 10001 01010 00100 00100 00100 00100],
      "Z" => %w[11111 00001 00010 00100 01000 10000 11111],
      "[" => %w[01110 01000 01000 01000 01000 01000 01110],
      "\\" => %w[10000 01000 00100 00010 00001 00000 00000],
      "]" => %w[01110 00010 00010 00010 00010 00010 01110],
      "^" => %w[00100 01010 10001 00000 00000 00000 00000],
      "_" => %w[00000 00000 00000 00000 00000 00000 11111],
      "`" => %w[01000 00100 00010 00000 00000 00000 00000],
      "{" => %w[00010 00100 00100 01000 00100 00100 00010],
      "|" => %w[00100 00100 00100 00000 00100 00100 00100],
      "}" => %w[01000 00100 00100 00010 00100 00100 01000],
      "~" => %w[00000 00000 01001 10110 00000 00000 00000]
    }.freeze

    GLYPH_WIDTH = 5
    GLYPH_HEIGHT = 7
    LETTER_SPACING = 1

    module_function

    def display_text(value)
      value.to_s.upcase.each_char.map { |character| GLYPHS.key?(character) ? character : "?" }.join
    end

    def advance(scale)
      (GLYPH_WIDTH + LETTER_SPACING) * scale
    end

    def line_height(scale)
      (GLYPH_HEIGHT + 2) * scale
    end

    def fit(value, max_width:, scale:)
      display_text(value).first([ max_width / advance(scale), 1 ].max)
    end

    def wrap(value, max_width:, scale:)
      limit = [ max_width / advance(scale), 1 ].max
      display_text(value).split("\n", -1).flat_map do |paragraph|
        wrap_paragraph(paragraph, limit)
      end
    end

    def image(value, scale:)
      text = display_text(value)
      width = [ text.length * advance(scale), 1 ].max
      height = GLYPH_HEIGHT * scale
      pixels = "\xff".b * (width * height)

      each_pixel(text, scale:) { |x, y| pixels.setbyte((y * width) + x, 0) }

      Vips::Image.new_from_memory(pixels, width, height, 1, :uchar)
    end

    def each_pixel(value, scale:)
      return enum_for(__method__, value, scale:) unless block_given?

      display_text(value).each_char.with_index do |character, character_index|
        GLYPHS.fetch(character, GLYPHS.fetch("?")).each_with_index do |row, row_index|
          row.each_char.with_index do |pixel, column_index|
            next unless pixel == "1"

            scale.times do |y_offset|
              scale.times do |x_offset|
                x = (character_index * advance(scale)) + (column_index * scale) + x_offset
                y = (row_index * scale) + y_offset
                yield x, y
              end
            end
          end
        end
      end
    end

    def wrap_paragraph(paragraph, limit)
      return [ "" ] if paragraph.empty?

      paragraph.split(/\s+/).each_with_object([]) do |word, lines|
        word.chars.each_slice(limit).map(&:join).each do |part|
          if lines.empty? || part.length == limit || lines.last.length + 1 + part.length > limit
            lines << part
          else
            lines[-1] = "#{lines.last} #{part}"
          end
        end
      end
    end
    private_class_method :wrap_paragraph
  end
end
