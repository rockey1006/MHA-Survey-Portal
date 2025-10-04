require "test_helper"

class StudentRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @advisor = users(:advisor)
  end

  test "admin can view student records" do
    sign_in @admin

    get student_records_path
    assert_response :success
  assert_includes response.body, "Student Records"
  assert_includes response.body, "Student User"
  assert_includes response.body, "Student Two"
  end

  test "advisor sees only assigned students" do
    sign_in @advisor

    get student_records_path
    assert_response :success
  assert_includes response.body, "Student User"
  assert_not_includes response.body, "Student Two"
  end

  test "unauthenticated user redirected" do
    get student_records_path
    assert_response :redirect
  end
end
