require "test_helper"

class AdvisorImpersonationsControllerUnitTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  tests AdvisorImpersonationsController

  setup do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  test "destroy signs out and redirects when impersonator missing" do
    sign_in users(:advisor)

    session[:impersonator_user_id] = -123
    session[:impersonation_kind] = "advisor"

    delete :destroy

    assert_redirected_to new_user_session_path
    assert_match(/expired/i, flash[:alert].to_s)
  end
end
