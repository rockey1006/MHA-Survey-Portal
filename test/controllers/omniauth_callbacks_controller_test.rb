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

  test "TAMU email redirects to sign in when provisioning returns nil" do
    email = "provisioning_failure@tamu.edu"
    mock_oauth(email: email)

    User.stub :from_google, nil do
      get user_google_oauth2_omniauth_callback_path, params: { role: "student" }
    end

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match(/not authorized/i, flash[:alert].to_s)
  ensure
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

  test "admin role redirects to admin dashboard" do
    user = users(:admin)
    @request.env["devise.mapping"] = Devise.mappings[:user]

    User.stub :from_google, user do
      get :google_oauth2
    end

    assert_redirected_to admin_dashboard_path
  end

  test "advisor role redirects to advisor dashboard" do
    user = users(:advisor)
    @request.env["devise.mapping"] = Devise.mappings[:user]

    User.stub :from_google, user do
      get :google_oauth2
    end

    assert_redirected_to advisor_dashboard_path
  end

  test "student auto assignment failures are rescued" do
    user = users(:student)
    @request.env["devise.mapping"] = Devise.mappings[:user]

    SurveyAssignments::AutoAssigner.stub :call, ->(**_args) { raise "boom" } do
      User.stub :from_google, user do
        get :google_oauth2
      end
    end

    assert_redirected_to student_dashboard_path
  end

  test "after_omniauth_failure_path_for returns sign in path" do
    assert_equal new_user_session_path, @controller.send(:after_omniauth_failure_path_for, :user)
  end

  test "unknown user role falls back to requested role param" do
    user = users(:student)
    @request.env["omniauth.params"] = { "role" => "advisor" }

    user.stub(:role, "mystery") do
      user.stub(:role_student?, false) do
        User.stub :from_google, user do
          @request.env["devise.mapping"] = Devise.mappings[:user]
          get :google_oauth2
        end
      end
    end

    assert_redirected_to advisor_dashboard_path
  end

  test "tamu_email accepts email.tamu.edu and rejects blank" do
    assert_equal true, @controller.send(:tamu_email?, "someone@email.tamu.edu")
    assert_equal false, @controller.send(:tamu_email?, "")
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
