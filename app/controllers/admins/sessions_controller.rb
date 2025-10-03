class Admins::SessionsController < Devise::SessionsController
  def after_sign_out_path_for(_resource_or_scope)
    new_admin_session_path
  end

  def after_sign_in_path_for(resource_or_scope)
    stored_location_for(resource_or_scope) || root_path
  end

  # Handle accidental or bot-driven GET requests to /admins/sign_out.
  # Devise expects DELETE for sign_out; some clients may still issue GET.
  # This action avoids treating "sign_out" as an Admin id and simply
  # redirects to the sign-in page (no DB lookup performed).
  def sign_out_get_fallback
    redirect_to after_sign_out_path_for(nil), allow_other_host: false
  end
end
