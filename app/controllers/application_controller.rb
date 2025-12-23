# Base controller providing authentication and shared helpers for downstream
# controllers. Ensures users are signed in and exposes current profile
# accessors for views.
class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :redirect_for_maintenance_mode
  before_action :authenticate_user!
  before_action :enforce_read_only_when_impersonating
  before_action :check_student_profile_complete
  before_action :load_notification_state, if: :user_signed_in?
  allow_browser versions: :modern

  helper_method :current_student, :current_advisor_profile, :impersonating?, :impersonator_user, :impersonation_kind

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

  private

  # Redirects students to profile setup if their profile is incomplete
  def check_student_profile_complete
    # Never block the role switching endpoint
    if controller_name == "dashboards" && action_name == "switch_role"
      return
    end
    if request&.path == "/switch_role"
      return
    end

    # When an admin is viewing as a student, keep the experience read-only and
    # avoid forcing profile completion redirects.
    return if impersonating?

    # Allow dashboard root redirect to proceed; gating happens on specific dashboards
    if controller_name == "dashboards" && action_name == "show"
      return
    end
    return if Rails.env.test?
    return unless user_signed_in?
    return unless current_user.role_student?
    return if current_student.nil?
    return if current_student.profile_complete?
    return if controller_name == "student_profiles" # Allow access to profile pages
    return if controller_name == "sessions" # Allow logout

    redirect_to edit_student_profile_path, alert: "Please complete your profile to continue."
  end

  # Preloads the notification count and recent records for the header dropdown.
  #
  # @return [void]
  def load_notification_state
    notifications_scope = current_user.notifications
    @unread_notification_count = notifications_scope.unread.count
    @recent_notifications = notifications_scope.recent.limit(10)
  end

  # When enabled, redirects non-admin users to the maintenance page.
  # Admins can still sign in and access admin tools to disable maintenance.
  def redirect_for_maintenance_mode
    return unless SiteSetting.maintenance_enabled?
    return if maintenance_mode_whitelisted_path?

    if current_user&.role_admin?
      return
    end

    redirect_to maintenance_path
  end

  def maintenance_mode_whitelisted_path?
    path = request.path.to_s

    return true if path == maintenance_path
    return true if path == "/up"

    # Allow authentication flow even while maintenance is enabled.
    return true if path.start_with?("/sign_in")
    return true if path.start_with?("/sign_out")
    return true if path.start_with?("/users/auth")

    # Allow assets to load on the maintenance page.
    return true if path.start_with?("/assets/")

    false
  end

  # Fallback semester label used when there is no ProgramSemester configured yet.
  #
  # @return [String]
  def fallback_semester_label
    Time.zone.now.strftime("%B %Y")
  end

  def impersonating?
    session[:impersonator_user_id].present?
  end

  def impersonator_user
    return nil unless impersonating?

    @impersonator_user ||= User.find_by(id: session[:impersonator_user_id])
  end

  def impersonation_kind
    session[:impersonation_kind].to_s
  end

  def enforce_read_only_when_impersonating
    return unless impersonating?
    return if request.get? || request.head?

    # Allow exiting impersonation (and signing out) even while in read-only mode.
    return if controller_name == "impersonations" && action_name == "destroy"
    return if controller_name == "advisor_impersonations" && action_name == "destroy"
    return if controller_name == "sessions" && action_name == "destroy"

    fallback_location = case current_user&.role.to_s
    when "advisor"
      advisor_dashboard_path
    when "admin"
      admin_dashboard_path
    else
      student_dashboard_path
    end

    redirect_back fallback_location:, alert: "Read-only while impersonating."
  end
end
