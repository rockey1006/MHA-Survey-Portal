require "test_helper"

class Admin::ProgramSemestersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in @admin
    @fall = program_semesters(:fall_2025)
    @spring = program_semesters(:spring_2026)
  end

  test "creates semester and can mark it current" do
    assert_difference "ProgramSemester.count", 1 do
      post admin_program_semesters_path, params: { program_semester: { name: "Summer 2027", current: "1" } }
    end

    assert_redirected_to admin_surveys_path(anchor: "semester-manager")

    new_semester = ProgramSemester.order(:created_at).last
    assert_equal "Summer 2027", new_semester.name
    assert new_semester.current?
    refute @fall.reload.current?, "previous current semester should be unset"
  end

  test "does not create semester with invalid data" do
    assert_no_difference "ProgramSemester.count" do
      post admin_program_semesters_path, params: { program_semester: { name: "" } }
    end

    assert_redirected_to admin_surveys_path(anchor: "semester-manager")
    assert_match "can't be blank", flash[:alert]
  end

  test "sets an existing semester as current" do
    refute @spring.current?

    patch make_current_admin_program_semester_path(@spring)
    assert_redirected_to admin_surveys_path(anchor: "semester-manager")

    assert @spring.reload.current?
    refute @fall.reload.current?
  end

  test "deletes a semester" do
    assert_difference "ProgramSemester.count", -1 do
      delete admin_program_semester_path(@spring)
    end

    assert_redirected_to admin_surveys_path(anchor: "semester-manager")
  end

  test "destroying the current semester assigns a fallback" do
    assert @fall.current?

    delete admin_program_semester_path(@fall)
    assert_redirected_to admin_surveys_path(anchor: "semester-manager")

    assert ProgramSemester.current.present?, "fallback semester should become current"
    assert_not_equal @fall.id, ProgramSemester.current.id
  end
end
