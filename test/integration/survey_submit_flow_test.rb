require "test_helper"

class SurveySubmitFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "student can submit survey and be redirected to survey response" do
    user = users(:student)
    sign_in user
    student = students(:student)
    survey = surveys(:fall_2025)

    # visit the survey show
    get survey_path(survey)
    assert_response :success

    # submit with required answers (use question fixture)
    answers = {}
    survey.questions.each do |q|
      answers[q.id.to_s] = q.question_type == "evidence" ? "https://drive.google.com/file/d/1" : "Answer"
    end

    post submit_survey_path(survey), params: { answers: answers }
    assert_redirected_to /survey_responses\//
  end
end
