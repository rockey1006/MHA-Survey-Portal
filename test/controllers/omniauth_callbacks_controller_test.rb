require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  test "rejects Google sign in for non-TAMU emails" do
    mock_oauth(email: "tester@gmail.com")

    get user_google_oauth2_omniauth_callback_path, params: { role: "student" }

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_equal "Please sign in with your TAMU email (@tamu.edu).", flash[:alert]
  end

  test "accepts Google sign in for TAMU emails" do
    email = "aggie@tamu.edu"
    mock_oauth(email: email)

    assert_difference -> { User.where(email: email).count }, 1 do
      get user_google_oauth2_omniauth_callback_path, params: { role: "student" }
    end

    assert_redirected_to student_dashboard_path
    follow_redirect!
    assert_equal I18n.t("devise.omniauth_callbacks.success", kind: "Google"), flash[:success]
    assert_equal email, User.find_by(email: email)&.email
  end

  private

  def mock_oauth(email:)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: SecureRandom.uuid,
      info: {
        email: email,
        name: "Test User",
        image: "https://example.org/avatar.png"
      }
    )
  end
end
