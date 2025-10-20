require "test_helper"

class SurveyAssignmentTest < ActiveSupport::TestCase
  test "assign survey to track creates SurveyAssignment record" do
    survey = surveys(:fall_2025)
    assert_difference "SurveyAssignment.count", 1 do
      SurveyAssignment.create!(survey: survey, track: "Executive")
    end
  end

  test "survey assignment belongs to survey via association" do
    sa = survey_assignments(:fall_2025_exec)
    assert sa.survey.present?
  end
end
