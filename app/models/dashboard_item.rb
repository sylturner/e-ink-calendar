class DashboardItem < ApplicationRecord
  belongs_to :dashboard

  scope :enabled, -> { where(enabled: true) }

  validates :component_key, presence: true
  validates :grid_x, :grid_y, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :grid_width, :grid_height, numericality: { only_integer: true, greater_than: 0 }
  validate :fits_within_dashboard_grid
  validate :does_not_overlap_another_item
  validate :settings_must_be_valid_json

  def settings_json
    JSON.pretty_generate(settings || {})
  end

  def settings_json=(value)
    @settings_json_error = nil
    self.settings = JSON.parse(value.presence || "{}")
  rescue JSON::ParserError
    @settings_json_error = "must be valid JSON"
  end

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

  def does_not_overlap_another_item
    return if dashboard.blank? || grid_x.blank? || grid_y.blank? || grid_width.blank? || grid_height.blank?
    return unless errors.empty?

    overlap = dashboard.dashboard_items.where.not(id: id).where(
      "grid_x < ? AND grid_x + grid_width > ? AND grid_y < ? AND grid_y + grid_height > ?",
      grid_x + grid_width,
      grid_x,
      grid_y + grid_height,
      grid_y
    )

    errors.add(:base, "overlaps another dashboard item") if overlap.exists?
  end

  def settings_must_be_valid_json
    errors.add(:settings, @settings_json_error) if @settings_json_error
  end
end
