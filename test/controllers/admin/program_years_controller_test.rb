require "test_helper"

class Admin::ProgramYearsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @student = users(:student)
  end

  test "non-admin is redirected" do
    sign_in @student

    post admin_program_years_path, params: { program_year: { value: 2028, position: 30, active: true } }

    assert_redirected_to dashboard_path
  end

  test "admin can create program year" do
    sign_in @admin

    assert_difference "ProgramYear.count", 1 do
      post admin_program_years_path, params: { program_year: { value: 2028, position: 30, active: true } }
    end

    assert_redirected_to admin_program_setup_path(tab: "years")
    assert_match(/created/i, flash[:notice].to_s)

    record = ProgramYear.order(:id).last
    assert_equal 2028, record.value
    assert_equal 30, record.position
    assert_equal true, record.active
  end

  test "admin create shows errors when invalid" do
    sign_in @admin

    assert_difference "ProgramYear.count", 0 do
      post admin_program_years_path, params: { program_year: { value: "", position: 10 } }
    end

    assert_redirected_to admin_program_setup_path(tab: "years")
    assert flash[:alert].present?
  end

  test "admin can update program year" do
    sign_in @admin

    year = ProgramYear.create!(value: 2029, position: 90, active: true)

    patch admin_program_year_path(year), params: { program_year: { value: 2030, position: 100, active: false } }

    assert_redirected_to admin_program_setup_path(tab: "years")

    year.reload
    assert_equal 2030, year.value
    assert_equal 100, year.position
    assert_equal false, year.active
  end

  test "admin update shows errors when invalid" do
    sign_in @admin

    year = ProgramYear.create!(value: 2031, position: 110, active: true)

    patch admin_program_year_path(year), params: { program_year: { value: "" } }

    assert_redirected_to admin_program_setup_path(tab: "years")
    assert flash[:alert].present?
  end

  test "admin can delete program year" do
    sign_in @admin

    year = ProgramYear.create!(value: 2032, position: 120, active: true)

    assert_difference "ProgramYear.count", -1 do
      delete admin_program_year_path(year)
    end

    assert_redirected_to admin_program_setup_path(tab: "years")
    assert_match(/deleted/i, flash[:notice].to_s)
  end
end
