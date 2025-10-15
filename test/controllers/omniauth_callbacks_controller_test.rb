require "test_helper"

class OmniauthCallbacksControllerTest < ActionController::TestCase
  tests OmniauthCallbacksController

  setup do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    @request.env["devise.scope"] = :user
    @routes = Rails.application.routes
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  test "rejects Google sign in for non-TAMU emails" do
    mock_oauth(email: "tester@gmail.com")
    @request.env["omniauth.params"] = { "role" => "student" }
    @request.env["devise.mapping"] = Devise.mappings[:user]

    post :google_oauth2

    assert_redirected_to new_user_session_path
    assert_equal "Please sign in with your TAMU email (@tamu.edu).", flash[:alert]
  end

  test "accepts Google sign in for TAMU emails" do
    email = "aggie@tamu.edu"
    mock_oauth(email: email)
    @request.env["omniauth.params"] = { "role" => "student" }
    @request.env["devise.mapping"] = Devise.mappings[:user]

    assert_difference -> { User.where(email: email).count }, 1 do
      post :google_oauth2
    end

    assert_redirected_to student_dashboard_path
    assert_equal I18n.t("devise.omniauth_callbacks.success", kind: "Google"), flash[:success]
    assert_equal email, User.find_by(email: email)&.email
  end

  private

  def mock_oauth(email:)
    @request.env["devise.mapping"] = Devise.mappings[:user]
    @request.env["devise.scope"] = :user
    path = "/users/auth/google_oauth2/callback"
    @request.env["PATH_INFO"] = path
    @request.env["ORIGINAL_FULLPATH"] = path
    @request.env["REQUEST_PATH"] = path
    @request.env["SCRIPT_NAME"] = ""

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: SecureRandom.uuid,
      info: {
        email: email,
        name: "Test User",
        image: "https://example.org/avatar.png"
      }
    )

    @request.env["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
  end
end
