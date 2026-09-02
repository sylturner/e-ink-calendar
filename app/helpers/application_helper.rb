module ApplicationHelper
  def pixel_text(value, scale:, label: value)
    text = Eink::PixelFont.display_text(value)
    width = [ text.length * Eink::PixelFont.advance(scale), 1 ].max
    height = Eink::PixelFont::GLYPH_HEIGHT * scale
    pixels = Eink::PixelFont.each_pixel(text, scale:).map do |x, y|
      tag.rect(x:, y:, width: scale, height: scale)
    end

    tag.svg(
      safe_join(pixels),
      class: "pixel-text",
      viewBox: "0 0 #{width} #{height}",
      width:,
      height:,
      role: "img",
      aria: { label: label },
      "shape-rendering": "crispEdges"
    )
  end
end
