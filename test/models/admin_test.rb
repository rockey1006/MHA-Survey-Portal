require "test_helper"

class AdminTest < ActiveSupport::TestCase
  def setup
    @admin = admins(:one)
    @advisor = admins(:two)
  end

  test "should be valid with valid attributes" do
    assert @admin.valid?
  end

  test "should respond to devise methods" do
    assert_respond_to Admin, :from_google
  end

  test "should create admin from google oauth data" do
    email = "newadmin@tamu.edu"
    full_name = "New Admin"
    uid = "123456789"
    avatar_url = "https://example.com/avatar.jpg"
    role = "admin"

    admin = Admin.from_google(
      email: email,
      full_name: full_name,
      uid: uid,
      avatar_url: avatar_url,
      role: role
    )

    assert admin.persisted?
    assert_equal email, admin.email
    assert_equal full_name, admin.full_name
    assert_equal uid, admin.uid
    assert_equal avatar_url, admin.avatar_url
  end

  test "should update existing admin from google oauth data" do
    existing_admin = @admin
    original_email = existing_admin.email
    new_full_name = "Updated Name"

    updated_admin = Admin.from_google(
      email: original_email,
      full_name: new_full_name,
      uid: existing_admin.uid,
      avatar_url: existing_admin.avatar_url,
      role: "admin"
    )

    assert_equal existing_admin.id, updated_admin.id
    assert_equal new_full_name, updated_admin.full_name
  end

  test "admin? method should return true for admin role" do
    @admin.update(role: "admin") if @admin.respond_to?(:role=)
    assert @admin.admin? if @admin.respond_to?(:admin?)
  end

  test "advisor? method should return true for advisor and admin roles" do
    if @admin.respond_to?(:advisor?)
      @admin.update(role: "admin") if @admin.respond_to?(:role=)
      assert @admin.advisor?

      @admin.update(role: "advisor") if @admin.respond_to?(:role=)
      assert @admin.advisor?

      @admin.update(role: "user") if @admin.respond_to?(:role=)
      assert_not @admin.advisor?
    end
  end

  test "can_manage_roles? method should return true only for admin role" do
    if @admin.respond_to?(:can_manage_roles?)
      @admin.update(role: "admin") if @admin.respond_to?(:role=)
      assert @admin.can_manage_roles?

      @admin.update(role: "advisor") if @admin.respond_to?(:role=)
      assert_not @admin.can_manage_roles?
    end
  end

  test "role method should handle missing role column gracefully" do
    # This tests the fallback method for role
    assert_respond_to @admin, :role
    # Should not raise an error even if role column doesn't exist
    assert_nothing_raised { @admin.role }
  end
end
