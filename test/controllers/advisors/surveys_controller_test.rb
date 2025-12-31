require "test_helper"

class Advisors::SurveysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @survey = surveys(:fall_2025)
    sign_in users(:advisor)
  end

  test "index redirects to shared assignments route" do
    get advisors_surveys_path
    assert_redirected_to assignments_surveys_path
  end

  test "show redirects to shared assignments route" do
    get "/advisors/surveys/#{@survey.id}"
    assert_redirected_to assignments_survey_path(@survey)
  end

end
