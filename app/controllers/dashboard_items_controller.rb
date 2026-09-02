class DashboardItemsController < ApplicationController
  before_action :set_dashboard_item, only: %i[ show edit update destroy ]

  # GET /dashboard_items or /dashboard_items.json
  def index
    @dashboard_items = DashboardItem.all
  end

  # GET /dashboard_items/1 or /dashboard_items/1.json
  def show
  end

  # GET /dashboard_items/new
  def new
    @dashboard_item = DashboardItem.new
  end

  # GET /dashboard_items/1/edit
  def edit
  end

  # POST /dashboard_items or /dashboard_items.json
  def create
    @dashboard_item = DashboardItem.new(dashboard_item_params)

    respond_to do |format|
      if @dashboard_item.save
        format.html { redirect_to @dashboard_item, notice: "Dashboard item was successfully created." }
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
        format.html { redirect_to @dashboard_item, notice: "Dashboard item was successfully updated.", status: :see_other }
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
      format.html { redirect_to dashboard_items_path, notice: "Dashboard item was successfully destroyed.", status: :see_other }
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
      params.expect(dashboard_item: [ :dashboard_id, :component_key, :settings, :grid_x, :grid_y, :grid_width, :grid_height, :enabled ])
    end
end
