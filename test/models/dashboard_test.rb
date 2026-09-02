require "test_helper"

class DashboardTest < ActiveSupport::TestCase
  test "uses the fixed eight-by-eight display grid" do
    dashboard = Dashboard.new(name: "Invalid grid", grid_columns: 7, grid_rows: 8)

    assert_not dashboard.valid?
    assert_includes dashboard.errors[:grid_columns], "must be equal to 8"
  end
end
