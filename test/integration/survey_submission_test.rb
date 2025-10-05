require "test_helper"

class SurveySubmissionTest < ActionDispatch::IntegrationTest
  setup do
    @survey = surveys(:fall_2025)
    @student_user = users(:student)
    @student = students(:student)
    @question = questions(:fall_q1)
  end

  test "student can submit survey responses" do
    sign_in @student_user

    assert_difference("SurveyResponse.where(student: @student, survey: @survey, status: SurveyResponse.statuses[:submitted]).count", 1) do
      post submit_survey_path(@survey), params: {
        answers: {
          @question.question_id => "Confident"
        }
      }
    end

    survey_response = SurveyResponse.find_by(student: @student, survey: @survey)
    assert survey_response.status_submitted?
    assert_equal "Confident", survey_response.question_responses.find_by(question: @question).answer

    assert_redirected_to survey_response_path(survey_response)
    follow_redirect!
    assert_response :success
  end
end
