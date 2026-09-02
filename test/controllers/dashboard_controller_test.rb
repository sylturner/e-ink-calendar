require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows the singleton dashboard" do
    get current_dashboard_url

    assert_response :success
    assert_select "section.dashboard-grid"
    assert_select "section.dashboard-grid svg.pixel-text[shape-rendering='crispEdges']", minimum: 1
    assert_select "canvas.pixel-text", false
  end

  test "serves an ESP32-compatible bitmap frame" do
    get dashboard_bmp_url

    assert_response :success
    assert_equal "image/bmp", response.media_type
    assert_equal "BM", response.body.byteslice(0, 2)
    assert_equal 48_062, response.body.bytesize
    assert_equal 62, response.body.byteslice(10, 4).unpack1("V")
    assert_equal 800, response.body.byteslice(18, 4).unpack1("V")
    assert_equal 480, response.body.byteslice(22, 4).unpack1("V")
    assert_equal 1, response.body.byteslice(28, 2).unpack1("v")
  end
end
