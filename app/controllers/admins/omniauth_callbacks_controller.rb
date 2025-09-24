class Admins::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Skip CSRF verification for OAuth callbacks since they come from external sources
  skip_before_action :verify_authenticity_token, only: [:google_oauth2, :failure]
  
  def google_oauth2
    # Debug: Log the OAuth params
    Rails.logger.debug "OAuth params: #{request.env['omniauth.params']}"
    
    # Get role from the request params (stored when user clicked login)
    role = request.env['omniauth.params']['role']
    Rails.logger.debug "Role from params: #{role}"
    
    admin = Admin.from_google(**from_google_params.merge(role: role))
    Rails.logger.debug "Admin created/found: #{admin.inspect}"
    Rails.logger.debug "Admin role: #{admin.role}"
    
    if admin.present?
      sign_out_all_scopes
      flash[:success] = t 'devise.omniauth_callbacks.success', kind: 'Google'
      sign_in(admin, event: :authentication)
      
      # Redirect based on role with fallback
      redirect_path = case admin.role
                     when 'admin'
                       admin_dashboard_path
                     when 'advisor'
                       advisor_dashboard_path
                     when 'student'
                       student_dashboard_path
                     else
                       # If no role set, use the login role parameter
                       case role
                       when 'student'
                         student_dashboard_path
                       when 'advisor'
                         advisor_dashboard_path
                       else
                         root_path
                       end
                     end
      
      Rails.logger.debug "Redirecting to: #{redirect_path}"
      redirect_to redirect_path
    else
      flash[:alert] = t 'devise.omniauth_callbacks.failure', kind: 'Google', reason: "#{auth.info.email} is not authorized."
      redirect_to new_admin_session_path
    end
  end

  protected

  def after_omniauth_failure_path_for(_scope)
    new_admin_session_path
  end

  def after_sign_in_path_for(resource_or_scope)
    # This method is overridden by our custom logic above
    stored_location_for(resource_or_scope) || root_path
  end

  private

  def from_google_params
    @from_google_params ||= {
      uid: auth.uid,
      email: auth.info.email,
      full_name: auth.info.name,
      avatar_url: auth.info.image
    }
  end

  def auth
    @auth ||= request.env['omniauth.auth']
  end
end