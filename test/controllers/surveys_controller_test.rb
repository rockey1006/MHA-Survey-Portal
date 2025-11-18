require "test_helper"

class SurveysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @student_user = users(:student)
    @student = students(:student) || Student.first
    @survey = surveys(:fall_2025)
  end

  test "submit redirects when student missing" do
    # no signed in user -> Devise redirects to sign_in
    post submit_survey_path(@survey), params: { answers: {} }
    assert_redirected_to new_user_session_path
  end

  test "submit shows errors for missing required answers" do
    sign_in @student_user
    # Force a required question by marking first question required in test
    q = @survey.questions.first
    q.update!(is_required: true) if q

    post submit_survey_path(@survey), params: { answers: {} }
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "submit persists answers and redirects on success" do
    sign_in @student_user
    answers = {}
    @survey.questions.limit(2).each do |q|
      answers[q.id.to_s] = "Sample answer #{q.id}"
    end
    post submit_survey_path(@survey), params: { answers: answers }
    # SurveyResponse.build returns a PORO; ensure redirect goes to a survey_response id path
    assert response.redirect?
    location = response.location || headers["Location"]
    assert_match %r{/survey_responses/\d+-\d+}, location
    follow_redirect!
    assert_match /Survey submitted successfully!/, response.body
  end

  test "show redirects students with completed surveys to survey response" do
    sign_in @student_user
    assignment = survey_assignments(:residential_assignment)
    assignment.update!(completed_at: Time.current)
    survey_response = SurveyResponse.build(student: @student, survey: @survey)

    get survey_path(@survey)

    assert_redirected_to survey_response_path(survey_response)
    follow_redirect!
    assert_match /already been submitted/i, response.body
  end

  test "save_progress redirects when survey already submitted" do
    sign_in @student_user
    assignment = survey_assignments(:residential_assignment)
    assignment.update!(completed_at: Time.current)
    survey_response = SurveyResponse.build(student: @student, survey: @survey)

    post save_progress_survey_path(@survey), params: { answers: { "1" => "data" } }

    assert_redirected_to survey_response_path(survey_response)
  end

  test "submit redirects when survey already submitted" do
    sign_in @student_user
    assignment = survey_assignments(:residential_assignment)
    assignment.update!(completed_at: Time.current)
    survey_response = SurveyResponse.build(student: @student, survey: @survey)

    post submit_survey_path(@survey), params: { answers: {} }

    assert_redirected_to survey_response_path(survey_response)
  end

  test "index shows only surveys for the student's track" do
    sign_in @student_user

    get surveys_path

    assert_response :success
    assert_includes response.body, "Fall 2025 Health Assessment"
    refute_includes response.body, "Spring 2025 Health Assessment"
  end

  test "index prompts profile completion when track missing" do
    @student.update!(track: nil)
    sign_in @student_user

    get surveys_path

    assert_response :success
    assert_includes response.body, "Finish setting up your profile"
  ensure
    @student.update!(track: "Residential")
  end

  test "index shows current semester badge" do
    sign_in @student_user

    ProgramSemester.current.update!(name: "Winter 2099")

    get surveys_path

    assert_response :success
    assert_includes response.body, "Winter 2099"
  end

  test "index falls back to current month when no semester configured" do
    sign_in @student_user
    ProgramSemester.delete_all

    get surveys_path

    assert_response :success
    assert_includes response.body, Time.zone.now.strftime("%B %Y")
  end
end
