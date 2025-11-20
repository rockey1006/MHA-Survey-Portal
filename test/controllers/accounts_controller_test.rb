# frozen_string_literal: true

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # Use fixture user for authentication testing
    @user = users(:student)
  end

  test "redirects to sign in when not authenticated" do
    get edit_account_path

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "shows edit page for authenticated user" do
    sign_in @user

    get edit_account_path

    assert_response :success
    # Sanity-check that we rendered the account edit form
    assert_includes @response.body, "Account Information"
  end

  test "updates account successfully and redirects back to edit with notice" do
    sign_in @user

    patch account_path, params: { user: { name: "Updated Name" } }

    assert_redirected_to edit_account_path
    assert_equal "Your account information has been updated.", flash[:notice]

    @user.reload
    assert_equal "Updated Name", @user.name
  end

  test "re-renders edit with alert when update fails" do
    sign_in @user

    # Temporarily force User#update to fail so that we hit the else branch
    original_update = User.instance_method(:update)
    User.define_method(:update) { |*args| false }

    patch account_path, params: { user: { name: "Still Original" } }

    assert_response :unprocessable_entity
    assert_equal "Please correct the errors below.", flash[:alert]
    # We should still be on the edit page
    assert_includes @response.body, "Account Information"

    @user.reload
    assert_equal "Student User", @user.name
  ensure
    # Restore the original implementation of User#update
    User.define_method(:update, original_update)
  end

  test "only permits name parameter in account_params" do
    sign_in @user

    # Try to update email (should be ignored by strong parameters)
    patch account_path, params: { user: { name: "New Name", email: "hacker@example.com" } }

    @user.reload
    assert_equal "New Name", @user.name
    assert_equal "student@example.com", @user.email
  end

  test "handles missing user parameter gracefully" do
    sign_in @user

    # Send invalid params without user key
    # In Rails, this may be caught and handled gracefully rather than raising
    begin
      patch account_path, params: { name: "Invalid" }
      # If no exception, verify nothing changed
      @user.reload
      assert_equal "Student User", @user.name
    rescue ActionController::ParameterMissing => e
      # If exception is raised, that's also acceptable
      assert_includes e.message, "user"
    end
  end

  test "edit displays user account information" do
    sign_in @user

    get edit_account_path

    assert_response :success
    # Verify the page shows the current user's name
    assert_includes @response.body, @user.name
  end

  test "update changes user information in database" do
    sign_in @user

    patch account_path, params: { user: { name: "Test Name" } }

    assert_redirected_to edit_account_path
    @user.reload
    assert_equal "Test Name", @user.name
  end

  test "successful update redirects with notice flash message" do
    sign_in @user

    patch account_path, params: { user: { name: "Flash Test" } }

    assert_redirected_to edit_account_path
    follow_redirect!
    assert_equal "Your account information has been updated.", flash[:notice]
  end

  test "failed update displays error message" do
    sign_in @user

    # Force validation failure
    original_update = User.instance_method(:update)
    User.define_method(:update) { |*args| false }

    patch account_path, params: { user: { name: "Fail" } }

    assert_response :unprocessable_entity
    assert_equal "Please correct the errors below.", flash[:alert]
  ensure
    User.define_method(:update, original_update)
  end

  test "update with empty name fails validation" do
    sign_in @user

    # User model requires name presence, should fail validation
    patch account_path, params: { user: { name: "" } }

    assert_response :unprocessable_entity
    @user.reload
    assert_equal "Student User", @user.name
  end

  test "update with whitespace name preserves whitespace" do
    sign_in @user

    patch account_path, params: { user: { name: "  Spaced Name  " } }

    assert_redirected_to edit_account_path
    @user.reload
    assert_equal "  Spaced Name  ", @user.name
  end
end
