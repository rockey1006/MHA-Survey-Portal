require "test_helper"
require "nokogiri"

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

  test "switch_role redirects with notice when already viewing selected role" do
    sign_in @student

    post switch_role_path, params: { role: "student" }

    assert_redirected_to student_dashboard_path
    follow_redirect!
    assert_match(/already viewing/i, flash[:notice].to_s)
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

  test "show falls back to student dashboard for unknown role" do
    user = @student
    user.update_column(:role, "mystery")

    sign_in user
    get dashboard_path
    assert_redirected_to student_dashboard_path
  ensure
    user.update_column(:role, "student")
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
    assert_nil flash[:alert]
  end

  test "manage_members shows an alert for advisors" do
    sign_in @advisor

    get manage_members_path

    assert_redirected_to dashboard_path
    assert_match(/access denied/i, flash[:alert].to_s)
  end

  test "manage_members lists users for admin" do
    sign_in @admin
    get manage_members_path
    assert_response :success
  assert_includes response.body, @student.email
  end

  test "manage_members supports searching" do
    sign_in @admin

    get manage_members_path, params: { q: "student@example.com" }

    assert_response :success
    assert_includes response.body, "student@example.com"
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

  test "update_roles logs admin activity" do
    sign_in @admin
    payload = { @other_student.id => "advisor" }

    assert_difference -> { AdminActivityLog.count }, 1 do
      patch update_roles_path, params: { role_updates: payload }
    end

    activity = AdminActivityLog.order(created_at: :desc).first
    assert_equal "role_update", activity.action
    assert_equal @admin, activity.admin
  ensure
    @other_student.update!(role: "student")
  end

  test "update_roles returns alert when all updates fail" do
    sign_in @admin

    payload = {
      @admin.id => "student",     # cannot change own role
      999999 => "advisor",        # user missing
      @student.id => "not-a-role" # invalid role
    }

    patch update_roles_path, params: { role_updates: payload }

    assert_redirected_to manage_members_path
    follow_redirect!
    assert_match(/role update errors/i, flash[:alert].to_s)
  end

  test "update_roles reports no changes needed" do
    sign_in @admin

    patch update_roles_path, params: { role_updates: { @student.id => "student" } }

    assert_redirected_to manage_members_path
    follow_redirect!
    assert_match(/no role changes were needed/i, flash[:notice].to_s)
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
    assert_includes response.body, "Save Changes"
    assert_includes response.body, "advisor-management-form"
    assert_includes response.body, "track_updates"
  end

  test "manage_students supports searching" do
    sign_in @admin

    get manage_students_path, params: { q: students(:student).user.email }

    assert_response :success
    assert_includes response.body, students(:student).user.email
  end

  test "advisor dashboard recreates missing advisor profile" do
    advisor_user = users(:advisor)
    Advisor.where(advisor_id: advisor_user.id).delete_all
    advisor_user.reload

    sign_in advisor_user

    assert_difference -> { Advisor.where(advisor_id: advisor_user.id).count }, 1 do
      get advisor_dashboard_path
    end

    assert_response :success
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

  test "update_student_advisor logs admin activity" do
    sign_in @admin
    student = students(:student)

    assert_difference -> { AdminActivityLog.count }, 1 do
      patch update_student_advisor_path(student), params: { student: { advisor_id: advisors(:other_advisor).advisor_id } }
    end

    activity = AdminActivityLog.order(created_at: :desc).first
    assert_equal "advisor_assignment", activity.action
    assert_equal @admin, activity.admin
    assert_equal student, activity.subject
  ensure
    student.update!(advisor: advisors(:advisor))
  end

  test "update_student_advisors applies bulk changes" do
    sign_in @admin

    student = students(:student)
    other_student = students(:other_student)

    payload = {
      student.student_id => advisors(:other_advisor).advisor_id,
      other_student.student_id => ""
    }

    patch update_student_advisors_path, params: { advisor_updates: payload }
    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match "Updated", flash[:notice]
    assert_equal advisors(:other_advisor).advisor_id, student.reload.advisor_id
  ensure
    student.update!(advisor: advisors(:advisor))
    other_student.update!(advisor: advisors(:other_advisor))
  end

  test "update_student_advisors changes track and logs activity" do
    sign_in @admin

    student = students(:student)
    original_track = student.track

    assert_difference -> { AdminActivityLog.where(action: "track_update").count }, 1 do
      patch update_student_advisors_path, params: { track_updates: { student.student_id => "executive" } }
    end

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match "Updated 1 track", flash[:notice]
    assert_equal "executive", student.reload.track
  ensure
    student.update!(track: original_track)
  end

  test "update_student_advisors rejects invalid track selection" do
    sign_in @admin

    student = students(:student)

    patch update_student_advisors_path, params: { track_updates: { student.student_id => "not-a-track" } }

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/track update errors/i, flash[:alert].to_s)
    assert_match(/invalid track selection/i, flash[:alert].to_s)
  end

  test "update_student_advisors rejects blank track selection when currently assigned" do
    sign_in @admin

    student = students(:student)

    patch update_student_advisors_path, params: { track_updates: { student.student_id => "" } }

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/track update errors/i, flash[:alert].to_s)
    assert_match(/track selection is required/i, flash[:alert].to_s)
  end

  test "update_student_advisors returns alert when no changes submitted" do
    sign_in @admin

    patch update_student_advisors_path, params: {}

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/no student changes were submitted/i, flash[:alert].to_s)
  end

  test "update_student_advisors reports missing students in both advisor and track updates" do
    sign_in @admin

    missing_id = "999999999"

    patch update_student_advisors_path, params: {
      advisor_updates: { missing_id => advisors(:advisor).advisor_id },
      track_updates: { missing_id => "executive" }
    }

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/student ##{missing_id} not found/i, flash[:alert].to_s)
  end

  test "update_student_advisors reports advisor not found" do
    sign_in @admin

    student = students(:student)

    patch update_student_advisors_path, params: { advisor_updates: { student.student_id => "999999" } }

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/advisor update errors/i, flash[:alert].to_s)
    assert_match(/advisor not found/i, flash[:alert].to_s)
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

  test "student dashboard only shows surveys assigned to the student" do
    Student.find(@student.id).update!(program_year: 2026) if Student.find_by(student_id: @student.id)&.program_year.blank?
    sign_in @student

    get student_dashboard_path

    assert_response :success
    assert_includes response.body, "Fall 2025 Health Assessment"
    refute_includes response.body, "Spring 2025 Health Assessment"

    assignment = survey_assignments(:residential_assignment)
    expected_availability = ApplicationController.helpers.survey_availability_note(assignment.available_until)
    assert_includes response.body, expected_availability
  end

  test "student dashboard renders even when auto-assigner raises" do
    sign_in @student

    SurveyAssignments::AutoAssigner.stub(:call, ->(student:) { raise "boom" }) do
      get student_dashboard_path
      assert_response :success
    end
  end

  test "student dashboard redirects when current_student is missing" do
    sign_in @advisor

    get student_dashboard_path

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match "Student profile not found", flash[:alert].to_s
  end

  test "update_student_advisors reports no changes when payload matches current state" do
    sign_in @admin

    student = students(:student)

    patch update_student_advisors_path, params: {
      advisor_updates: { student.student_id => student.advisor_id.to_s },
      track_updates: { student.student_id => student.track }
    }

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/no student changes were needed/i, flash[:notice].to_s)
  end

  test "update_student_advisors ignores blank track when student track is already blank" do
    sign_in @admin

    student = students(:student)
    student.update!(track: nil)

    patch update_student_advisors_path, params: {
      track_updates: { student.student_id => "" }
    }

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/no student changes were needed/i, flash[:notice].to_s)
    assert_nil flash[:alert]
  ensure
    student.update!(track: "residential")
  end

  test "update_student_advisors reports failures when a track update raises" do
    sign_in @admin

    student = students(:student)

    AdminActivityLog.stub(:record!, ->(**_) { raise StandardError, "boom" }) do
      patch update_student_advisors_path, params: { track_updates: { student.student_id => "executive" } }
    end

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/track update errors/i, flash[:alert].to_s)
    assert_match(/boom/i, flash[:alert].to_s)
  end

  test "update_student_advisors reports failures when an advisor update raises" do
    sign_in @admin

    student = students(:student)
    new_advisor_id = advisors(:other_advisor).advisor_id

    original_update = Student.instance_method(:update!)
    Student.define_method(:update!) do |*_args|
      raise StandardError, "boom"
    end
    begin
      patch update_student_advisors_path, params: { advisor_updates: { student.student_id => new_advisor_id.to_s } }
    ensure
      Student.define_method(:update!, original_update)
    end

    assert_redirected_to manage_students_path
    follow_redirect!
    assert_match(/advisor update errors/i, flash[:alert].to_s)
    assert_match(/boom/i, flash[:alert].to_s)
  end

  test "admin dashboard activity feed includes fallbacks for unknown actions" do
    sign_in @admin

    SurveyChangeLog.create!(
      survey: nil,
      admin: @admin,
      action: "preview",
      description: "",
      created_at: Time.current,
      updated_at: Time.current
    )

    AdminActivityLog.record!(admin: @admin, action: "something-else", description: "Custom admin action")

    get admin_dashboard_path
    assert_response :success
    assert_includes response.body, "Survey previewed"
    assert_includes response.body, "Custom admin action"
  end

  test "update_roles reports failures when an update raises" do
    sign_in @admin

    target = User.find(@other_student.id)
    def target.update!(*_args)
      raise StandardError, "boom"
    end

    original = User.method(:find_by)
    User.stub(:find_by, ->(id:) { id.to_s == target.id.to_s ? target : original.call(id: id) }) do
      patch update_roles_path, params: { role_updates: { target.id => "advisor" } }
    end

    assert_redirected_to manage_members_path
    follow_redirect!
    assert_match(/role update errors/i, flash[:alert].to_s)
    assert_match(/boom/i, flash[:alert].to_s)
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

  test "advisor dashboard shows total reports count" do
    sign_in @advisor

    get advisor_dashboard_path
    assert_response :success

    reports_description = extract_feature_description(response.body, "Reports")
    assert_equal "1 generated", reports_description
  end

  test "admin dashboard shows total reports count" do
    sign_in @admin

    get admin_dashboard_path
    assert_response :success

    reports_description = extract_feature_description(response.body, "Reports")
    assert_equal "3 generated", reports_description
  end

  test "admin dashboard shows populated activity feed" do
    sign_in @admin

    get admin_dashboard_path
    assert_response :success

    assert_includes response.body, "Survey created: Fall 2025 Health Assessment"
    assert_includes response.body, "Feedback updated: Student User"
  end

  private

  def extract_feature_description(html, title)
    doc = Nokogiri::HTML.parse(html)

    # Current dashboard tile markup
    tile_node = doc.css(".c-tile").find do |tile|
      tile.at_css(".c-tile__title")&.text&.strip == title
    end
    tile_node&.at_css(".c-tile__description")&.text&.strip
  end
end
