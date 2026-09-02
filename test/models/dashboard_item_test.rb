require "test_helper"

class DashboardItemTest < ActiveSupport::TestCase
  test "accepts a tile that fits the dashboard" do
    item = dashboards(:one).dashboard_items.build(
      component_key: "quote",
      settings: {},
      grid_x: 2,
      grid_y: 6,
      grid_width: 6,
      grid_height: 2
    )

    assert_predicate item, :valid?
  end

  test "rejects a tile that extends past the dashboard edge" do
    item = dashboards(:one).dashboard_items.build(
      component_key: "quote",
      settings: {},
      grid_x: 4,
      grid_y: 6,
      grid_width: 6,
      grid_height: 2
    )

    assert_not item.valid?
    assert_includes item.errors[:grid_width], "extends past the dashboard's right edge"
  end
end
