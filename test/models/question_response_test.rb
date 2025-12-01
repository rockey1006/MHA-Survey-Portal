require "test_helper"

class StudentQuestionTest < ActiveSupport::TestCase
  setup do
    @student = students(:student)
    @advisor = advisors(:advisor)
    @question = questions(:fall_q1)
    @category = categories(:clinical_skills)
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

  test "evidence questions require Google-hosted link" do
    evidence_question = @category.questions.create!(
      question_text: "Provide evidence",
      question_order: 2,
      question_type: "evidence",
      is_required: true
    )

    sq = StudentQuestion.new(student: @student, advisor: @advisor, question: evidence_question)
    sq.answer = "https://example.com/not-drive"

    assert sq.invalid?
    assert_includes sq.errors[:response_value], "must be a publicly shareable Google link"
  end

  test "valid Google Drive or Google Sites links are accepted for evidence questions" do
    evidence_question = @category.questions.create!(
      question_text: "Upload proof",
      question_order: 3,
      question_type: "evidence",
      is_required: true
    )

    sq = StudentQuestion.new(student: @student, advisor: @advisor, question: evidence_question)
    sq.answer = "https://drive.google.com/file/d/12345/view"

    assert sq.valid?

    sq.answer = "https://sites.google.com/view/sample/page"
    assert sq.valid?, sq.errors.full_messages.to_sentence
  end
end

class QuestionResponseTest < ActiveSupport::TestCase
  setup do
    @student = students(:student)
    @question = questions(:fall_q1)
  end

  test "survey returns associated survey" do
    response = QuestionResponse.new(student: @student, question: @question)
    assert_equal @question.category.survey, response.survey
  end

  test "survey returns nil without question" do
    response = QuestionResponse.new
    assert_nil response.survey
  end
end
