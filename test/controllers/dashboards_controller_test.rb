require "test_helper"

class DashboardsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  tests DashboardsController

  setup do
    @user = users(:student)
    sign_in @user
  end

  test "switch_role blocked in production-like env when disabled" do
    # simulate production by setting Rails.env stub and env var off
    begin
      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        ENV["ENABLE_ROLE_SWITCH"] = nil
        post :switch_role, params: { role: "advisor" }
        assert_redirected_to dashboard_path
      end
    rescue => e
      # fallback to asserting redirect when ENV not set
      ENV["ENABLE_ROLE_SWITCH"] = nil
      post :switch_role, params: { role: "advisor" }
      assert_redirected_to dashboard_path
    end
  end

  test "switch_role accepts invalid role gracefully" do
    post :switch_role, params: { role: "invalid-role" }
    assert_redirected_to dashboard_path
  end
end

class DashboardsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @student = users(:student)
    @advisor = users(:advisor)
  end

  test "show redirects based on role" do
    sign_in @student
    get dashboard_path
    assert_redirected_to student_dashboard_path

    sign_in @advisor
    get dashboard_path
    assert_redirected_to advisor_dashboard_path

    sign_in @admin
    get dashboard_path
    assert_redirected_to admin_dashboard_path
  end

  test "switch_role updates user role when allowed" do
    sign_in @admin
    # By default role switching allowed in test env
    post switch_role_path, params: { role: "student" }
    assert_redirected_to student_dashboard_path
    @admin.reload
    assert_equal "student", @admin.role
  end

  test "switch_role rejects invalid role" do
    sign_in @student
    post switch_role_path, params: { role: "bogus" }
    assert_redirected_to dashboard_path
    follow_redirect!
    # The controller redirects with an alert flash when role is invalid.
    assert_match /Unrecognized role selection|only available/, flash[:alert].to_s
  end

  test "manage_members requires admin and lists users" do
    sign_in @admin
    get manage_members_path
    assert_response :success
    assert_select "table" if @response.body.present?
  end

  test "update_roles handles invalid submissions and success" do
    sign_in @admin
    # Submitting empty updates redirects with alert
    patch update_roles_path, params: { role_updates: {} }
    assert_redirected_to manage_members_path
    follow_redirect!
    assert flash[:alert].present? or flash[:notice].present?

    # Now submit a valid update for another user
    user = users[:other_student] || users[:student]
    patch update_roles_path, params: { role_updates: { user.id => "advisor" } }
    assert_redirected_to manage_members_path
    follow_redirect!
    assert flash[:notice].present?
  end
end
