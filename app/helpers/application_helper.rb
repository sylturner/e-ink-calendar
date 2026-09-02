module ApplicationHelper
  def eink_text(value, font:, label: value)
    glyphs = font.glyphs(value).map do |glyph|
      tag.span(
        "",
        class: "eink-glyph",
        style: "background-position: -#{glyph.x}px -#{glyph.y}px",
        aria: { hidden: true }
      )
    end

    tag.span(
      safe_join(glyphs),
      class: "eink-text",
      style: "--eink-atlas: url(#{asset_path(font.asset_path)}); --eink-atlas-width: #{font.atlas_width}px; --eink-atlas-height: #{font.atlas_height}px; --eink-cell-width: #{font.cell_width}px; --eink-cell-height: #{font.cell_height}px",
      role: "img",
      aria: { label: label }
    )
  end
end
