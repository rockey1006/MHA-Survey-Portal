require "test_helper"

class StudentQuestionTest < ActiveSupport::TestCase
  test "drive url regex accepts Google Drive links and rejects others" do
    good = "https://drive.google.com/file/d/1abcdef/view?usp=sharing"
    bad = "https://example.com/not-drive"
    assert_match StudentQuestion::DRIVE_URL_REGEX, good
    refute_match StudentQuestion::DRIVE_URL_REGEX, bad
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

  test "evidence link validation requires google drive url" do
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
    assert_includes sq.errors[:response_value], "must be a Google Drive file or folder link"

    sq.response_value = "https://drive.google.com/file/d/123/view"
    assert sq.valid?, sq.errors.full_messages.to_sentence
  end
end
