require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  setup do
    @feedback = feedbacks(:advisor_feedback)
  end

  test "average_score must be numeric" do
    @feedback.average_score = "not-a-number"
    refute @feedback.valid?
    assert_includes @feedback.errors[:average_score], "is not a number"
  end

  test "survey uniqueness enforced" do
    duplicate = Feedback.new(
      student: students(:other_student),
      advisor: advisors(:other_advisor),
      category: categories(:clinical_skills),
      survey: @feedback.survey,
      average_score: 3.5
    )

    refute duplicate.valid?
    assert_includes duplicate.errors[:survey_id], "has already been taken"
  end

  test "valid feedback saves successfully" do
    record = Feedback.new(
      student: students(:student),
      advisor: advisors(:advisor),
      category: categories(:clinical_skills),
      survey: surveys(:spring_2025),
      average_score: 4.2,
      comments: "Consistent progress"
    )

    assert record.save, record.errors.full_messages.to_sentence
  end
end
