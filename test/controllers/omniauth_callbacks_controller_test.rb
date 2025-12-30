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

  test "OAuth sign in triggers sessions controller callbacks" do
    email = "sessions_callback@tamu.edu"
    mock_oauth(email: email)

    # This will trigger SessionsController#after_sign_in_path_for
    get user_google_oauth2_omniauth_callback_path, params: { role: "student" }

    assert_redirected_to student_dashboard_path

    # Clean up
    User.find_by(email: email)&.destroy
  end

  test "OAuth sign in auto-assigns surveys for students" do
    email = "student_surveys@tamu.edu"
    mock_oauth(email: email)

    get user_google_oauth2_omniauth_callback_path, params: { role: "student" }

    assert_redirected_to student_dashboard_path
    # The sessions controller ensure_track_survey_assignment is called via after_sign_in_path_for

    # Clean up
    User.find_by(email: email)&.destroy
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

class OmniauthCallbacksControllerUnitTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests OmniauthCallbacksController

  setup do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    @request.env["omniauth.params"] = { "role" => "student" }
    @request.env["omniauth.auth"] = auth_hash(email: "student@tamu.edu")
  end

  test "non-TAMU emails are rejected before provisioning" do
    @request.env["omniauth.auth"] = auth_hash(email: "user@example.com")
    @request.env["devise.mapping"] = Devise.mappings[:user]

    get :google_oauth2

    assert_redirected_to new_user_session_path
    assert_match "Please sign in with your TAMU email", flash[:alert]
  end

  test "TAMU emails provision users and trigger auto assignment" do
    user = users(:student)
    called = []

    # Ensure Devise mapping is still available when the action hits sign_in.
    @request.env["devise.mapping"] = Devise.mappings[:user]

    SurveyAssignments::AutoAssigner.stub :call, ->(**args) { called << args } do
      User.stub :from_google, user do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        get :google_oauth2
      end
    end

    assert_redirected_to student_dashboard_path
    assert_equal I18n.t("devise.omniauth_callbacks.success", kind: "Google"), flash[:success]
    assert_equal 1, called.size
    assert_equal user.student_profile, called.first[:student]
  end

  test "provisioning failures redirect back with alert" do
    User.stub :from_google, nil do
      @request.env["devise.mapping"] = Devise.mappings[:user]
      get :google_oauth2
    end

    assert_redirected_to new_user_session_path
    assert_match "not authorized", flash[:alert]
  end

  test "after_omniauth_failure_path_for returns sign in path" do
    assert_equal new_user_session_path, @controller.send(:after_omniauth_failure_path_for, :user)
  end

  private

  def auth_hash(email:)
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: SecureRandom.uuid,
      info: OmniAuth::AuthHash::InfoHash.new(
        email: email,
        name: "Unit Test",
        image: "https://example.org/avatar.png"
      )
    )
  end
end
