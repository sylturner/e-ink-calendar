class DashboardItemsController < ApplicationController
  before_action :set_dashboard_item, only: %i[ show edit update destroy ]

  # GET /dashboard_items or /dashboard_items.json
  def index
    @dashboard_items = Dashboard.default.dashboard_items.order(:grid_y, :grid_x)
  end

  # GET /dashboard_items/1 or /dashboard_items/1.json
  def show
  end

  # GET /dashboard_items/new
  def new
    @dashboard_item = Dashboard.default.dashboard_items.build(
      component_key: "quote",
      settings: {},
      grid_x: 0,
      grid_y: 0,
      grid_width: 2,
      grid_height: 2
    )
  end

  # GET /dashboard_items/1/edit
  def edit
  end

  # POST /dashboard_items or /dashboard_items.json
  def create
    @dashboard_item = Dashboard.default.dashboard_items.build(dashboard_item_params.except(:dashboard_id))

    respond_to do |format|
      if @dashboard_item.save
        format.html { redirect_to edit_current_dashboard_path, notice: "Component added." }
        format.json { render :show, status: :created, location: @dashboard_item }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @dashboard_item.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /dashboard_items/1 or /dashboard_items/1.json
  def update
    respond_to do |format|
      if @dashboard_item.update(dashboard_item_params)
        format.html { redirect_to edit_current_dashboard_path, notice: "Component updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @dashboard_item }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @dashboard_item.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /dashboard_items/1 or /dashboard_items/1.json
  def destroy
    @dashboard_item.destroy!

    respond_to do |format|
      format.html { redirect_to edit_current_dashboard_path, notice: "Component removed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dashboard_item
      @dashboard_item = DashboardItem.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def dashboard_item_params
      params.expect(dashboard_item: [ :dashboard_id, :component_key, :settings, :settings_json, :grid_x, :grid_y, :grid_width, :grid_height, :enabled ])
    end
end
