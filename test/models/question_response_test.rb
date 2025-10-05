require "test_helper"

class QuestionResponseTest < ActiveSupport::TestCase
  test "answer serialization preserves arrays" do
    survey_response = survey_responses(:student_fall)
    question = questions(:fall_q1)

    qr = QuestionResponse.new(survey_response: survey_response, question: question)
    qr.answer = [ "Option A", "Option B" ]
    assert_equal [ "Option A", "Option B" ], qr.answer
    assert_equal [ "Option A", "Option B" ].to_json, qr.read_attribute(:answer)
  end

  test "answer accepts strings" do
    survey_response = survey_responses(:student_fall)
    question = questions(:fall_q1)

    qr = QuestionResponse.new(survey_response: survey_response, question: question)
    qr.answer = "Yes"
    assert_equal "Yes", qr.answer
  end
end
