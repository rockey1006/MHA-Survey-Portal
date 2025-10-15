class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Skip CSRF verification for OAuth callbacks since they come from external sources
  skip_before_action :verify_authenticity_token, only: [ :google_oauth2, :failure ]

  def google_oauth2
    # Debug: Log the OAuth params
    Rails.logger.debug "OAuth params: #{request.env['omniauth.params']}"

    # Get role from the request params (stored when user clicked login)
    role = request.env["omniauth.params"]["role"]
    Rails.logger.debug "Role from params: #{role}"

    email = auth.info.email.to_s.downcase

    unless tamu_email?(email)
      Rails.logger.warn "Blocked OAuth login for non-TAMU email: #{email}"
      flash[:alert] = "Please sign in with your TAMU email (@tamu.edu)."
      redirect_to new_user_session_path and return
    end

    user = User.from_google(**from_google_params.merge(email:, role: role))
    Rails.logger.debug "User created/found: #{user.inspect}"
    Rails.logger.debug "User role: #{user.role}"

    if user.present?
      sign_out_all_scopes
      flash[:success] = t "devise.omniauth_callbacks.success", kind: "Google"
      sign_in(user, event: :authentication)

      # Redirect based on role with fallback
      redirect_path = case user.role
      when "admin"
                       admin_dashboard_path
      when "advisor"
                       advisor_dashboard_path
      when "student"
                       student_dashboard_path
      else
                       case role
                       when "student"
                         student_dashboard_path
                       when "advisor"
                         advisor_dashboard_path
                       else
                         dashboard_path
                       end
      end

      Rails.logger.debug "Redirecting to: #{redirect_path}"
      redirect_to redirect_path
    else
      flash[:alert] = t "devise.omniauth_callbacks.failure", kind: "Google", reason: "#{auth.info.email} is not authorized."
      redirect_to new_user_session_path
    end
  end

  protected

  def after_omniauth_failure_path_for(_scope)
    new_user_session_path
  end

  def after_sign_in_path_for(resource_or_scope)
    # This method is overridden by our custom logic above
    stored_location_for(resource_or_scope) || dashboard_path
  end

  private

  def from_google_params
    @from_google_params ||= {
      uid: auth.uid,
      email: auth.info.email.to_s.downcase,
      name: auth.info.name,
      avatar_url: auth.info.image
    }
  end

  def auth
    @auth ||= request.env["omniauth.auth"]
  end

  def tamu_email?(email)
    return false if email.blank?

    normalized_email = email.downcase
    normalized_email.ends_with?("@tamu.edu") || normalized_email.ends_with?("@email.tamu.edu")
  end
end
