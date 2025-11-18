require "test_helper"

class StudentRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @advisor = users(:advisor)
  end

  test "admin can see all students and feedback summaries" do
    sign_in @admin

    get student_records_path
    assert_response :success
    assert_includes response.body, "Student Records"
  assert_includes response.body, users(:student).name
  assert_includes response.body, users(:other_student).name
  assert_includes response.body, "Has feedback"
  end

  test "advisor sees all students" do
    sign_in @advisor

    get student_records_path
    assert_response :success
    assert_includes response.body, users(:student).name
    assert_includes response.body, users(:other_student).name
  end

  test "unauthenticated user redirected" do
    get student_records_path
    assert_response :redirect
  end
end
