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

  test "student record status remains pending until submission completed" do
    student = students(:student)
    survey = surveys(:fall_2025)
    question = survey.questions.first || survey.categories.first.questions.create!(
      question_text: "Fixture question",
      question_order: 1,
      question_type: "short_answer",
      is_required: true
    )

    StudentQuestion.where(student_id: student.student_id, question_id: question.id).delete_all
    StudentQuestion.create!(student_id: student.student_id, question: question, response_value: "Test response")

    controller = StudentRecordsController.new
    records = controller.send(:build_student_records, [ student ])
    row = find_row(records, student, survey)
    assert_not_nil row, "Expected to find a student row in records"
    assert_equal "Pending", row[:status]
    assert_nil row[:completed_at]

    assignment = survey_assignments(:residential_assignment)
    completion_time = Time.current
    assignment.update!(completed_at: completion_time)

    controller_after = StudentRecordsController.new
    records_after = controller_after.send(:build_student_records, [ student ])
    row_after = find_row(records_after, student, survey)
    assert_not_nil row_after, "Expected to find updated student row"
    assert_equal "Completed", row_after[:status]
    assert_in_delta completion_time.to_i, row_after[:completed_at].to_i, 1
  end

  private

  def find_row(records, student, survey)
    Array(records).each do |semester_block|
      Array(semester_block[:surveys]).each do |survey_block|
        next unless survey_block[:survey].id == survey.id

        row = survey_block[:rows].find { |entry| entry[:student].student_id == student.student_id }
        return row if row
      end
    end
    nil
  end
end
