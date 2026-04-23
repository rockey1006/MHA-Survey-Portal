require "test_helper"
require "csv"

class Admin::CompetenciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @advisor = users(:advisor)
    @other_advisor = users(:other_advisor)
    @student = users(:student)
    @other_student = users(:other_student)
    students(:student).update!(advisor_id: @advisor.id)
    students(:other_student).update!(advisor_id: @other_advisor.id)
  end

  test "advisor can view competencies matrix for assigned students only" do
    sign_in @advisor

    get admin_competencies_path

    assert_response :success
    assert_includes response.body, "Competencies"
    assert_includes response.body, "1 student"
    refute_includes response.body, "Course competency rule"
    refute_includes response.body, "Global setting applied to course-derived competency values for all users."
    refute_includes response.body, @other_student.email
  end

  test "student is redirected without admin warning" do
    sign_in @student

    get admin_competencies_path

    assert_redirected_to dashboard_path
    assert_nil flash[:alert]
  end

  test "admin can view competencies matrix" do
    sign_in @admin

    get admin_competencies_path

    assert_response :success
    assert_includes response.body, "Competencies"
    assert_includes response.body, "Course competency rule"
    assert_includes response.body, "Global setting applied to course-derived competency values for all users."
  end

  test "advisor filter options stay scoped to assigned students" do
    sign_in @advisor

    get admin_competencies_path, params: { advisor_id: @other_advisor.id }

    assert_response :success
    assert_includes response.body, "0 students"
    refute_includes response.body, @other_student.email
  end

  test "admin can update global course competency rule" do
    sign_in @admin

    patch course_rule_admin_competencies_path, params: { course_competency_rule: "avg" }

    assert_redirected_to admin_competencies_path
    assert_equal "avg", SiteSetting.course_competency_rule
  ensure
    SiteSetting.set_course_competency_rule!(CourseCompetencyRule::DEFAULT_RULE)
  end

  test "advisor cannot update global course competency rule" do
    sign_in @advisor

    patch course_rule_admin_competencies_path, params: { course_competency_rule: "avg" }

    assert_redirected_to dashboard_path
    assert_equal CourseCompetencyRule::DEFAULT_RULE, SiteSetting.course_competency_rule
  ensure
    SiteSetting.set_course_competency_rule!(CourseCompetencyRule::DEFAULT_RULE)
  end

  test "admin can export competencies as csv" do
    sign_in @admin

    get export_admin_competencies_path(format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type

    csv = CSV.parse(response.body, headers: true)
    assert_includes csv.headers, "Student ID"
    assert_includes csv.headers, "Course Competency Rule"
    assert csv.any?, "Expected exported CSV to include at least one row"
  end

  test "advisor export remains scoped to assigned students" do
    sign_in @advisor

    get export_admin_competencies_path(format: :csv)

    assert_response :success
    csv = CSV.parse(response.body, headers: true)
    student_names = csv.map { |row| row["Student Name"] }.uniq

    assert_includes student_names, @student.display_name
    refute_includes student_names, @other_student.display_name
  end

  test "changing course competency rule updates matrix values for all rule options program-wide" do
    sign_in @admin
    competency_title = Reports::DataAggregator::COMPETENCY_TITLES.first
    create_course_rating(student: students(:student), competency_title: competency_title, level: 3.0)
    create_course_rating(student: students(:student), competency_title: competency_title, level: 4.0)
    create_course_rating(student: students(:student), competency_title: competency_title, level: 1.0)
    create_course_rating(student: students(:student), competency_title: competency_title, level: 2.0)
    create_course_rating(student: students(:student), competency_title: competency_title, level: 1.0)

    {
      "max" => { value: 4.0, label: "Max" },
      "min" => { value: 1.0, label: "Min" },
      "avg" => { value: 2.2, label: "Avg" },
      "ceil_avg" => { value: 3.0, label: "Ceil(avg)" },
      "floor_avg" => { value: 2.0, label: "Floor(avg)" }
    }.each do |rule, expected|
      patch course_rule_admin_competencies_path, params: { course_competency_rule: rule }
      assert_redirected_to admin_competencies_path

      payload = Admin::CompetencyMatrix.new(params: {}, actor_user: @admin).call
      row = payload[:students].find { |student_row| student_row[:id] == students(:student).student_id }
      assert_in_delta expected[:value], row.dig(:ratings, competency_title, :course_rating), 0.001
      assert_equal expected[:label], payload[:course_competency_rule_label]
    end
  ensure
    SiteSetting.set_course_competency_rule!(CourseCompetencyRule::DEFAULT_RULE)
  end

  private

  def create_course_rating(student:, competency_title:, level:)
    batch = GradeImportBatch.create!(
      uploaded_by: @admin,
      status: "completed",
      summary: { "dry_run" => false }
    )

    GradeCompetencyRating.create!(
      grade_import_batch: batch,
      student: student,
      competency_title: competency_title,
      aggregated_level: level,
      aggregation_rule: "max",
      evidence_count: 1
    )
  end
end
