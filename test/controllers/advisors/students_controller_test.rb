require "test_helper"

class Advisors::StudentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @student = students(:student)
    sign_in users(:advisor)
  end

  test "update changes track with valid input" do
    patch advisors_student_path(@student), params: { student: { track: "executive" } }
    assert_redirected_to advisors_student_path(@student)
    assert_equal "executive", @student.reload.track
    assert_match "Track changed", flash[:notice]
  end

  test "update rejects invalid track values" do
    patch advisors_student_path(@student), params: { student: { track: "" } }
    assert_redirected_to student_records_path
    assert_match "Unable to change track", flash[:alert]
  end

  test "update handles missing student" do
    patch advisors_student_path("missing"), params: { student: { track: "executive" } }
    assert_redirected_to student_records_path
    assert_equal "Student not found.", flash[:alert]
  end
end
