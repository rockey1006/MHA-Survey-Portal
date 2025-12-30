require "test_helper"

class Admin::MajorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @student = users(:student)
  end

  test "non-admin is redirected" do
    sign_in @student

    post admin_majors_path, params: { major: { name: "MPH" } }

    assert_redirected_to dashboard_path
  end

  test "admin can create major" do
    sign_in @admin

    assert_difference "Major.count", 1 do
      post admin_majors_path, params: { major: { name: "MPH" } }
    end

    assert_redirected_to admin_program_setup_path(tab: "majors")
    assert_match(/created/i, flash[:notice].to_s)

    record = Major.order(:id).last
    assert_equal "MPH", record.name
  end

  test "admin create shows errors when invalid" do
    sign_in @admin

    assert_difference "Major.count", 0 do
      post admin_majors_path, params: { major: { name: "" } }
    end

    assert_redirected_to admin_program_setup_path(tab: "majors")
    assert flash[:alert].present?
  end

  test "admin can update major" do
    sign_in @admin

    major = Major.create!(name: "Before")

    patch admin_major_path(major), params: { major: { name: "After" } }

    assert_redirected_to admin_program_setup_path(tab: "majors")

    major.reload
    assert_equal "After", major.name
  end

  test "admin update shows errors when invalid" do
    sign_in @admin

    major = Major.create!(name: "Before")

    patch admin_major_path(major), params: { major: { name: "" } }

    assert_redirected_to admin_program_setup_path(tab: "majors")
    assert flash[:alert].present?
  end

  test "admin can delete major" do
    sign_in @admin

    major = Major.create!(name: "Delete")

    assert_difference "Major.count", -1 do
      delete admin_major_path(major)
    end

    assert_redirected_to admin_program_setup_path(tab: "majors")
    assert_match(/deleted/i, flash[:notice].to_s)
  end
end
