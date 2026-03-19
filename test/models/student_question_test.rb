require "test_helper"

class StudentQuestionTest < ActiveSupport::TestCase
  test "google url regex accepts google sites domains and rejects others" do
    drive_link = "https://drive.google.com/file/d/1abcdef/view?usp=sharing"
    sites_link = "https://sites.google.com/view/sample-site/home"
    bad = "https://example.com/not-drive"
    refute_match StudentQuestion::GOOGLE_URL_REGEX, drive_link
    assert_match StudentQuestion::GOOGLE_URL_REGEX, sites_link
    refute_match StudentQuestion::GOOGLE_URL_REGEX, bad
  end

  test "creating and updating a student question persists answers" do
    student = students(:student)
    q = questions(:fall_q1)
    sq = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: q.id)
    sq.answer = "Test answer"
    sq.save!
    assert_equal "Test answer", StudentQuestion.find_by(id: sq.id).answer
  end

  test "answer serializes non-string values to json" do
    student = students(:student)
    question = questions(:fall_q1)
    sq = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question.id)
    sq.answer = { score: 5 }
    sq.save!

    stored = sq.reload.read_attribute(:response_value)
    assert_equal "{\"score\":5}", stored
    assert_equal({ "score" => 5 }, sq.answer)
  end

  test "normalize response trims whitespace" do
    student = students(:student)
    question = questions(:fall_q1)
    sq = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question.id)
    sq.update!(response_value: "  padded answer  ")

    assert_equal "padded answer", sq.reload.response_value
  end

  test "evidence link validation requires google sites url" do
    student = students(:student)
    category = categories(:clinical_skills)
    evidence_question = category.questions.create!(
      question_text: "Provide evidence",
      question_type: "evidence",
      question_order: 99,
      is_required: false
    )

    sq = StudentQuestion.new(
      student: student,
      question: evidence_question,
      response_value: "https://example.com/not-drive"
    )

    refute sq.valid?
    assert_includes sq.errors[:response_value], "must be a published Google Sites link"

    sq.response_value = "https://drive.google.com/file/d/123/view"
    refute sq.valid?
    assert_includes sq.errors[:response_value], "must be a published Google Sites link"

    sq.response_value = "https://sites.google.com/view/demo/page"
    assert sq.valid?, sq.errors.full_messages.to_sentence
  end

  test "integer question enforces whole number and bounds" do
    student = students(:student)
    category = categories(:clinical_skills)
    integer_question = category.questions.create!(
      question_text: "How many hours per week do you work on average?",
      question_type: "integer",
      question_order: 199,
      is_required: false,
      integer_min: 1,
      integer_max: 80
    )

    sq = StudentQuestion.new(
      student: student,
      question: integer_question,
      response_value: "0"
    )

    refute sq.valid?
    assert_includes sq.errors[:response_value], "must be greater than or equal to 1"

    sq.response_value = "3.5"
    refute sq.valid?
    assert_includes sq.errors[:response_value], "must be a whole number"

    sq.response_value = "abc"
    refute sq.valid?
    assert_includes sq.errors[:response_value], "must be a whole number"

    sq.response_value = "120"
    refute sq.valid?
    assert_includes sq.errors[:response_value], "must be less than or equal to 80"

    sq.response_value = "12"
    assert sq.valid?, sq.errors.full_messages.to_sentence
  end
end
