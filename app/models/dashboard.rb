class Dashboard < ApplicationRecord
  GRID_COLUMNS = 8
  GRID_ROWS = 8

  has_many :dashboard_items, dependent: :destroy

  validates :name, presence: true
  validates :theme, inclusion: { in: Eink::Theme::PRESETS.keys }
  validates :grid_columns, numericality: { only_integer: true, equal_to: GRID_COLUMNS }
  validates :grid_rows, numericality: { only_integer: true, equal_to: GRID_ROWS }

  def self.default
    find_or_create_by!(name: "Default dashboard") do |dashboard|
      dashboard.grid_columns = GRID_COLUMNS
      dashboard.grid_rows = GRID_ROWS
    end
  end
end
