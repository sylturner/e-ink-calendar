module Eink
  class Theme
    PRESETS = {
      "pixelify" => {
        label: "Pixelify",
        title_font: "pixelify-sans-20",
        body_font: "pixelify-sans-20",
        footer_font: "pixelify-sans-20"
      },
      "vhs_terminal" => {
        label: "VHS terminal",
        title_font: "vhs-gothic-16",
        body_font: "pixel-operator-8-16",
        footer_font: "pixel-operator-8-bold-16"
      },
      "arcade" => {
        label: "Arcade",
        title_font: "upheaval-24",
        body_font: "pixel-operator-8-bold-16",
        footer_font: "pixel-operator-8-16"
      }
    }.freeze

    def self.fetch(key)
      PRESETS.fetch(key) { PRESETS.fetch("pixelify") }
    end

    def self.options
      PRESETS.map { |key, preset| [ preset.fetch(:label), key ] }
    end
  end
end
