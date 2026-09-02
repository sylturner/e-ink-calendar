class Dashboard < ApplicationRecord
  GRID_COLUMNS = 8
  GRID_ROWS = 8

  has_many :dashboard_items, dependent: :destroy

  validates :name, presence: true
  validates :grid_columns, numericality: { only_integer: true, equal_to: GRID_COLUMNS }
  validates :grid_rows, numericality: { only_integer: true, equal_to: GRID_ROWS }
end
