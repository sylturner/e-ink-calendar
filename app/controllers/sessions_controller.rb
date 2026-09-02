class SessionsController < ApplicationController
  skip_before_action :require_dashboard_password

  def new
    redirect_to current_dashboard_path unless dashboard_password_configured?
  end

  def create
    if password_matches?(params.expect(:password))
      session[:dashboard_authenticated] = true
      redirect_to current_dashboard_path, notice: "Dashboard unlocked."
    else
      flash.now[:alert] = "That password did not match."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    session.delete(:dashboard_authenticated)
    redirect_to new_session_path, notice: "Dashboard locked."
  end

  private

  def password_matches?(submitted_password)
    expected = ENV.fetch("DASHBOARD_PASSWORD")
    submitted = submitted_password.to_s
    return false unless submitted.bytesize == expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(submitted, expected)
  end
end
