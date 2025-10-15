require "test_helper"

class StudentQuestionTest < ActiveSupport::TestCase
  setup do
    @student = students(:student)
    @advisor = advisors(:advisor)
    @question = questions(:fall_q1)
  end

  test "answer serialization preserves arrays" do
    sq = StudentQuestion.new(student: @student, advisor: @advisor, question: @question)
    sq.answer = [ "Option A", "Option B" ]

    assert_equal [ "Option A", "Option B" ], sq.answer
    assert_equal [ "Option A", "Option B" ].to_json, sq.read_attribute(:response_value)
  end

  test "answer accepts strings" do
    sq = StudentQuestion.new(student: @student, advisor: @advisor, question: @question)
    sq.answer = "Yes"
    assert_equal "Yes", sq.answer
  end

  test "evidence questions require Google Drive link" do
    evidence_question = Question.create!(
      question: "Provide evidence",
      question_order: 2,
      question_type: "evidence",
      required: true
    )

    sq = StudentQuestion.new(student: @student, advisor: @advisor, question: evidence_question)
    sq.answer = "https://example.com/not-drive"

    assert sq.invalid?
    assert_includes sq.errors[:response_value], "must be a Google Drive file or folder link"
  end

  test "valid Google Drive links are accepted for evidence questions" do
    evidence_question = Question.create!(
      question: "Upload proof",
      question_order: 3,
      question_type: "evidence",
      required: true
    )

    sq = StudentQuestion.new(student: @student, advisor: @advisor, question: evidence_question)
    sq.answer = "https://drive.google.com/file/d/12345/view"

    assert sq.valid?
  end
end
