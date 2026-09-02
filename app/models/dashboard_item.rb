class DashboardItem < ApplicationRecord
  belongs_to :dashboard

  validates :component_key, presence: true
  validates :grid_x, :grid_y, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :grid_width, :grid_height, numericality: { only_integer: true, greater_than: 0 }
  validate :fits_within_dashboard_grid

  private

  def fits_within_dashboard_grid
    return if dashboard.blank? || grid_x.blank? || grid_y.blank? || grid_width.blank? || grid_height.blank?

    if grid_x + grid_width > dashboard.grid_columns
      errors.add(:grid_width, "extends past the dashboard's right edge")
    end

    if grid_y + grid_height > dashboard.grid_rows
      errors.add(:grid_height, "extends past the dashboard's bottom edge")
    end
  end
end
