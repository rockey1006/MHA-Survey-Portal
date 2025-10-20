require "application_system_test_case"

class SurveyUiTest < ApplicationSystemTestCase
  test "student views survey and sees questions" do
    user = users(:student)
    student = students(:student)

    driven_by :rack_test
    sign_in user
    visit survey_path(surveys(:fall_2025))

    assert_selector "form"
    assert_text "How do you rate your clinical skills?"
  end
end
