# Customizes Devise session behavior to support tailored redirects and GET
# fallbacks for sign-out requests.
class SessionsController < Devise::SessionsController
  layout "auth", only: [ :new ]

  # Destination after a user signs out.
  #
  # @return [String]
  def after_sign_out_path_for(_resource_or_scope)
    new_user_session_path
  end

  # Destination after a successful sign in, preferring stored location.
  #
  # @param resource_or_scope [Object]
  # @return [String]
  def after_sign_in_path_for(resource_or_scope)
    ensure_track_survey_assignment(resource_or_scope)
    stored_location_for(resource_or_scope) || dashboard_path
  end

  # Handle accidental or bot-driven GET requests to /sign_out.
  # Devise expects DELETE for sign_out; some clients may still issue GET.
  # This action avoids treating "sign_out" as a User id and simply
  # redirects to the sign-in page (no DB lookup performed).
  #
  # @return [void]
  def sign_out_get_fallback
    redirect_to after_sign_out_path_for(nil), allow_other_host: false
  end

  private

  def ensure_track_survey_assignment(resource_or_scope)
    user = resolve_user(resource_or_scope)
    return unless user&.role_student?

    student = user.student_profile
    return unless student

    SurveyAssignments::AutoAssigner.call(student: student)
  rescue StandardError => e
    Rails.logger.error(
      "Session auto-assign failed for user #{user&.id}: #{e.class}: #{e.message}"
    )
  end

  def resolve_user(resource_or_scope)
    return resource_or_scope if resource_or_scope.is_a?(User)
    return resource_or_scope.user if resource_or_scope.respond_to?(:user)

    current_user if respond_to?(:current_user, true)
  end
end
