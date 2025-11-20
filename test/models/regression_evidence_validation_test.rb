require "test_helper"

class RegressionEvidenceValidationTest < ActiveSupport::TestCase
  test "evidence question rejects non-drive links on submit" do
    survey = surveys(:fall_2025)
    category = survey.categories.first || survey.categories.create!(name: "Temp", description: "Temp")
    evidence_question = survey.questions.find_by(question_type: "evidence")
    evidence_question ||= Question.create!(
      category: category,
      question_text: "Upload evidence",
      question_order: 999,
      question_type: "evidence",
      is_required: false
    )

    student = students(:student)
    StudentQuestion.where(student_id: student.student_id, question_id: evidence_question.id).delete_all

    sq = StudentQuestion.new(student_id: student.student_id, question: evidence_question)
    sq.response_value = "https://example.com/not-drive"
    refute sq.valid?, "Expected evidence validation to reject non-drive links"
    assert_includes sq.errors[:response_value], "must be a Google Drive file or folder link"

    sq.response_value = "https://drive.google.com/file/d/abc/view"
    assert sq.valid?, "Expected evidence validation to accept drive links"
  end
end
