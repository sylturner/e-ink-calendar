class DashboardController < ApplicationController
  skip_before_action :require_dashboard_password, only: :bmp

  def show
    load_dashboard
  end

  def edit
    load_dashboard
  end

  def bmp
    dashboard = Dashboard.default
    frame = Eink::BmpRenderer.new(dashboard).render

    send_data frame,
      type: "image/bmp",
      disposition: "inline",
      filename: "dashboard.bmp"
  end

  private

  def load_dashboard
    @dashboard = Dashboard.default
    @dashboard_items = @dashboard.dashboard_items.enabled.order(:grid_y, :grid_x).to_a
    @panels_by_item_id = @dashboard_items.to_h do |item|
      [ item.id, Eink::ComponentRegistry.build(item).cached_panel ]
    end
  end
end
