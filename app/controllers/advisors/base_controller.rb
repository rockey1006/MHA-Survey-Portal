module Advisors
  class BaseController < ApplicationController
    before_action :require_advisor!

    helper_method :current_advisor_profile, :advisor_scope?

    private

    def require_advisor!
      return if current_user&.role_advisor? || current_user&.role_admin?

      redirect_to dashboard_path, alert: "Advisor access required."
    end

    def advisor_scope?
      current_user&.role_advisor?
    end
  end
end
