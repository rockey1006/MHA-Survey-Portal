# Base controller providing authentication and shared helpers for downstream
# controllers. Ensures users are signed in and exposes current profile
# accessors for views.
class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :authenticate_user!
  allow_browser versions: :modern

  helper_method :current_student, :current_advisor_profile

  # @return [Student, nil] the authenticated user's student profile, if present
  def current_student
    return @current_student if defined?(@current_student)
    @current_student = current_user&.student_profile
  end

  # @return [Advisor, nil] the authenticated user's advisor profile, if present
  def current_advisor_profile
    return @current_advisor if defined?(@current_advisor)
    @current_advisor = current_user&.advisor_profile
  end
end
