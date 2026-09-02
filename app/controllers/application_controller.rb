class ApplicationController < ActionController::Base
  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_dashboard_password

  helper_method :dashboard_authenticated?, :dashboard_password_configured?

  private

  def require_dashboard_password
    return unless dashboard_password_configured?
    return if dashboard_authenticated?

    redirect_to new_session_path, alert: "Enter the dashboard password to continue."
  end

  def dashboard_authenticated?
    session[:dashboard_authenticated] == true
  end

  def dashboard_password_configured?
    ENV["DASHBOARD_PASSWORD"].present?
  end
end
