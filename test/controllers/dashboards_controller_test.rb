require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @student = users(:student)
    @advisor = users(:advisor)
    @other_student = users(:other_student)
  end

  test "switch_role blocked in production when disabled" do
    sign_in @student

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      ENV["ENABLE_ROLE_SWITCH"] = nil
      post switch_role_path, params: { role: "advisor" }
      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match "Role switching is only available", flash[:alert]
    end
  ensure
    ENV.delete("ENABLE_ROLE_SWITCH")
  end

  test "switch_role rejects invalid role" do
    sign_in @student
    post switch_role_path, params: { role: "invalid-role" }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match "Unrecognized role selection.", flash[:alert]
  end

  test "show redirects based on role" do
    sign_in @student
    get dashboard_path
    assert_redirected_to student_dashboard_path

    sign_in @advisor
    get dashboard_path
    assert_redirected_to advisor_dashboard_path

    sign_in @admin
    get dashboard_path
    assert_redirected_to admin_dashboard_path
  end

  test "switch_role updates user role when allowed" do
    sign_in @admin
    post switch_role_path, params: { role: "student" }
    assert_redirected_to student_dashboard_path
    @admin.reload
    assert_equal "student", @admin.role
  ensure
    @admin.update!(role: "admin")
  end

  test "manage_members requires admin" do
    sign_in @student
    get manage_members_path
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match "Access denied", flash[:alert]
  end

  test "manage_members lists users for admin" do
    sign_in @admin
    get manage_members_path
    assert_response :success
  assert_includes response.body, @student.email
  end

  test "update_roles handles empty submission" do
    sign_in @admin
    patch update_roles_path, params: { role_updates: {} }
    assert_redirected_to manage_members_path
    follow_redirect!
    assert_match "No role changes were submitted", flash[:alert]
  end

  test "update_roles processes successes and failures" do
    sign_in @admin
    payload = {
      @admin.id => "student", # cannot change own role
      999999 => "advisor",    # user missing
      @student.id => "invalid", # invalid role
      @other_student.id => "advisor" # valid update
    }

    patch update_roles_path, params: { role_updates: payload }
    assert_redirected_to manage_members_path
    follow_redirect!
  assert_match "Updated", flash[:notice]
  assert_match "cannot change your own role", flash[:notice]
    assert_equal "advisor", @other_student.reload.role
  ensure
    @other_student.update!(role: "student")
  end

  test "debug_users returns expected json" do
    sign_in @admin
    get debug_users_path
    assert_response :success

    payload = JSON.parse(response.body)
    assert payload.key?("users")
    assert payload.key?("role_counts")
  end

  test "manage_students lists advisees for advisor" do
    sign_in @advisor
    get manage_students_path
    assert_response :success
    assert_includes response.body, students(:student).user.name
  end

  test "manage_students for admin shows assignment controls" do
    sign_in @admin
    get manage_students_path
    assert_response :success
  assert_includes response.body, "Advisor"
  end

  test "update_student_advisor updates assignment" do
    sign_in @admin
    student = students(:student)
    patch update_student_advisor_path(student), params: { student: { advisor_id: advisors(:other_advisor).advisor_id } }
    assert_redirected_to manage_students_path
    assert_match "Advisor updated successfully", flash[:notice]
    assert_equal advisors(:other_advisor).advisor_id, student.reload.advisor_id
  ensure
    student.update!(advisor: advisors(:advisor))
  end

  test "student dashboard recreates missing profile" do
    user = users(:student)
    Student.where(student_id: user.id).delete_all
    user.reload

    sign_in user

    assert_difference -> { Student.where(student_id: user.id).count }, 1 do
      get student_dashboard_path
    end

    assert_response :success
  end

  test "student dashboard lists recent notifications" do
    user = users(:student)
    sign_in user

    Notification.delete_all
    Notification.create!(user: user, title: "Welcome", message: "Your dashboard now shows real alerts.")

    get student_dashboard_path

    assert_response :success
    assert_includes response.body, "Welcome"
  end

  test "advisor dashboard handles admin impersonation" do
    Admin.find_or_create_by!(admin_id: @admin.id)
    @admin.update!(role: "advisor")
    sign_in @admin

    get advisor_dashboard_path
    assert_response :success
  assert_includes response.body, "Advisor Dashboard"
  ensure
    @admin.update!(role: "admin")
  end

  test "admin dashboard aggregates metrics" do
    sign_in @admin
    get admin_dashboard_path
    assert_response :success
  assert_includes response.body, "Admin Dashboard"
  end
end
