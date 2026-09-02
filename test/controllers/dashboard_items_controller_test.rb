require "test_helper"

class DashboardItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dashboard_item = dashboard_items(:one)
  end

  test "should get index" do
    get dashboard_items_url
    assert_response :success
  end

  test "should get new" do
    get new_dashboard_item_url
    assert_response :success
  end

  test "should create dashboard_item" do
    assert_difference("DashboardItem.count") do
      post dashboard_items_url, params: { dashboard_item: { component_key: "quote", enabled: true, grid_height: 2, grid_width: 6, grid_x: 2, grid_y: 6, settings: {} } }
    end

    assert_redirected_to edit_current_dashboard_url
  end

  test "should show dashboard_item" do
    get dashboard_item_url(@dashboard_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_dashboard_item_url(@dashboard_item)
    assert_response :success
  end

  test "should update dashboard_item" do
    patch dashboard_item_url(@dashboard_item), params: { dashboard_item: { component_key: @dashboard_item.component_key, dashboard_id: @dashboard_item.dashboard_id, enabled: @dashboard_item.enabled, grid_height: @dashboard_item.grid_height, grid_width: @dashboard_item.grid_width, grid_x: @dashboard_item.grid_x, grid_y: @dashboard_item.grid_y, settings: @dashboard_item.settings } }
    assert_redirected_to edit_current_dashboard_url
  end

  test "should destroy dashboard_item" do
    assert_difference("DashboardItem.count", -1) do
      delete dashboard_item_url(@dashboard_item)
    end

    assert_redirected_to edit_current_dashboard_url
  end
end
