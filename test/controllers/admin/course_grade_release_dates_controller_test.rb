require "test_helper"

class Admin::CourseGradeReleaseDatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @advisor = users(:advisor)
    @survey = surveys(:fall_2025)
    @semester = @survey.program_semester
  end

  test "admin can view course grade release dates" do
    sign_in @admin

    get admin_course_grade_release_dates_path

    assert_response :success
    assert_includes response.body, "Course Grade Release Dates"
    assert_includes response.body, @semester.name
  end

  test "admin can set and clear a release date" do
    sign_in @admin
    release_at = 3.days.from_now.change(sec: 0)

    post admin_course_grade_release_dates_path, params: {
      course_grade_release_date: {
        program_semester_id: @semester.id,
        release_date: release_at.strftime("%Y-%m-%dT%H:%M")
      }
    }

    assert_redirected_to admin_course_grade_release_dates_path
    release = @semester.reload.course_grade_release_date
    assert_in_delta release_at.to_i, release.release_date.to_i, 60

    delete admin_course_grade_release_date_path(release)

    assert_redirected_to admin_course_grade_release_dates_path
    assert_nil @semester.reload.course_grade_release_date
  end

  test "advisor cannot manage course grade release dates" do
    sign_in @advisor

    get admin_course_grade_release_dates_path

    assert_redirected_to dashboard_path
  end
end
