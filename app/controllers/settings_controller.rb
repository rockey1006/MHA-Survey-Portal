class SettingsController < ApplicationController
  before_action :authenticate_user!

  # GET /settings
  def edit
    @user = current_user
  end

  # PATCH /settings
  def update
    @user = current_user
    if @user.update(settings_params)
      # Persisted successfully; updated_at will be updated automatically
      redirect_to request.referer.presence || root_path, notice: "Settings updated successfully."
    else
      flash.now[:alert] = "Please correct the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:language, :notifications_enabled, :text_scale_percent)
  end
end
