require "test_helper"

class SurveyResponseTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert survey_responses(:student_fall).valid?
  end

  test "approval pending returns true for submitted or under review" do
    sr = survey_responses(:student_fall)

    sr.status = SurveyResponse.statuses[:submitted]
    assert sr.approval_pending?

    sr.status = SurveyResponse.statuses[:under_review]
    assert sr.approval_pending?

    sr.status = SurveyResponse.statuses[:approved]
    assert_not sr.approval_pending?
  end

  test "associations resolve" do
    sr = survey_responses(:student_fall)

    assert_equal students(:student), sr.student
    assert_equal surveys(:fall_2025), sr.survey
    assert_equal advisors(:advisor), sr.advisor
  end
end
