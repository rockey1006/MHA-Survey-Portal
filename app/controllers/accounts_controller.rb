class AccountsController < ApplicationController
  before_action :authenticate_user!

  # Shows the current user's account info
  def edit
    @user = current_user
  end

  # Updates basic account fields (safe default: just the display name)
  def update
    @user = current_user

    if @user.update(account_params)
      redirect_to edit_account_path, notice: "Your account information has been updated."
    else
      flash.now[:alert] = "Please correct the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    # Keep this conservative so we don't accidentally break Devise
    params.require(:user).permit(:name)
  end
end
