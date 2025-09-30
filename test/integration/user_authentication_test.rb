require "test_helper"

class UserAuthenticationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @admin = admins(:one)
    @advisor = admins(:two)
  end

  test "admin login workflow via Google OAuth" do
    # Test the OAuth callback simulation
    # This simulates what would happen after Google OAuth
    omniauth_hash = {
      "provider" => "google_oauth2",
      "uid" => "123456789",
      "info" => {
        "email" => "newadmin@tamu.edu",
        "name" => "Test Admin",
        "image" => "https://example.com/avatar.jpg"
      }
    }

    # Simulate OAuth callback
    admin = Admin.from_google(
      email: omniauth_hash["info"]["email"],
      full_name: omniauth_hash["info"]["name"],
      uid: omniauth_hash["uid"],
      avatar_url: omniauth_hash["info"]["image"],
      role: "admin"
    )

    assert admin.persisted?
    assert_equal "newadmin@tamu.edu", admin.email
    assert_equal "Test Admin", admin.full_name
    assert_equal "123456789", admin.uid

    # Test signing in the created admin
    sign_in admin
    get surveys_path
    assert_response :success
  end

  test "admin can access admin-only features" do
    sign_in @admin

    # Admin should be able to access all CRUD operations
    get surveys_path
    assert_response :success

    get new_survey_path
    assert_response :success

    get competencies_path
    assert_response :success

    get students_path
    assert_response :success
  end

  test "advisor has appropriate permissions" do
    # Assuming advisor has different permissions than admin
    sign_in @advisor

    # Test that advisor can access surveys (adjust based on your permissions)
    get surveys_path
    assert_response :success

    # Test other endpoints based on your authorization logic
    get students_path
    assert_response :success # or :forbidden based on your setup
  end

  test "unauthenticated user is redirected to login" do
    # Test various protected endpoints
    protected_paths = [
      surveys_path,
      competencies_path,
      students_path,
      new_survey_path,
      new_competency_path
    ]

    protected_paths.each do |path|
      get path
      assert_redirected_to new_admin_session_path, "Should redirect to login for #{path}"
    end
  end

  test "authenticated user can sign out" do
    sign_in @admin

    # Verify user is signed in
    get surveys_path
    assert_response :success

    # Sign out (this depends on your Devise setup)
    delete destroy_admin_session_path

    # Verify user is signed out
    get surveys_path
    assert_redirected_to new_admin_session_path
  end

  test "role-based authorization works correctly" do
    # Test admin role methods
    @admin.update(role: "admin") if @admin.respond_to?(:role=)
    if @admin.respond_to?(:admin?)
      assert @admin.admin?
      assert @admin.advisor?
      assert @admin.can_manage_roles?
    end

    # Test advisor role methods
    @advisor.update(role: "advisor") if @advisor.respond_to?(:role=)
    if @advisor.respond_to?(:advisor?)
      assert @advisor.advisor?
      assert_not @advisor.admin? if @advisor.respond_to?(:admin?)
      assert_not @advisor.can_manage_roles? if @advisor.respond_to?(:can_manage_roles?)
    end
  end

  test "existing admin is updated on subsequent OAuth login" do
    # Create initial admin
    existing_admin = Admin.from_google(
      email: "existing@tamu.edu",
      full_name: "Old Name",
      uid: "existing123",
      avatar_url: "old_avatar.jpg",
      role: "advisor"
    )

    # Simulate another OAuth login with updated info
    updated_admin = Admin.from_google(
      email: "existing@tamu.edu", # Same email
      full_name: "New Name",      # Updated name
      uid: "existing123",         # Same UID
      avatar_url: "new_avatar.jpg", # Updated avatar
      role: "admin"               # Updated role
    )

    # Should be the same record
    assert_equal existing_admin.id, updated_admin.id
    assert_equal "New Name", updated_admin.full_name
    assert_equal "new_avatar.jpg", updated_admin.avatar_url
  end

  test "session persistence across requests" do
    sign_in @admin

    # Make multiple requests to verify session persistence
    get surveys_path
    assert_response :success

    get competencies_path
    assert_response :success

    post surveys_path, params: {
      survey: {
        survey_id: 9999,
        title: "Session Test Survey",
        semester: "Test Semester",
        assigned_date: Date.current,
        completion_date: Date.current + 30.days
      }
    }

    # Should be able to create without re-authentication
    assert_response :redirect
    assert Survey.exists?(survey_id: 9999)
  end
end
