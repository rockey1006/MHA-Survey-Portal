require "test_helper"

class AdminTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    @admin = @user.admin_profile || Admin.create!(admin_id: @user.id)
  end

  test "full_name delegates to user" do
    @user.update!(name: "Updated Admin")
    assert_equal "Updated Admin", @admin.full_name
  end

  test "role writer updates underlying user" do
    @admin.role = "advisor"
    @admin.save!

    assert_equal "advisor", @user.reload.role
  ensure
    @user.update!(role: "admin")
  end

  test "admin privilege helpers" do
    assert @admin.admin?

    @user.update!(role: "advisor")
    assert @admin.advisor?
    refute @admin.admin?
  ensure
    @user.update!(role: "admin")
  end

  test "save persists delegated attributes" do
    @admin.full_name = "Delegated Name"
    assert @admin.save
    assert_equal "Delegated Name", @user.reload.name
  end
end
