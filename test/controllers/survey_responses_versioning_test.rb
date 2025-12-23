require "test_helper"

class SurveyResponsesVersioningTest < ActionDispatch::IntegrationTest
  setup do
    @student_user = users(:student)
    @admin_user = users(:admin)
    @student = students(:student)
    @survey = surveys(:fall_2025)
  end

  test "survey response show supports version navigation" do
    sign_in @student_user

    # Create a version by submitting once.
    answers = {}
    @survey.questions.limit(1).each { |q| answers[q.id.to_s] = "A1" }
    post submit_survey_path(@survey), params: { answers: answers }
    assert_response :redirect

    # Create a second version by revising before due date.
    assignment = SurveyAssignment.find_by!(student_id: @student.student_id, survey_id: @survey.id)
    assignment.update!(due_date: 2.days.from_now)

    answers2 = {}
    @survey.questions.limit(1).each { |q| answers2[q.id.to_s] = "A2" }
    post submit_survey_path(@survey), params: { answers: answers2 }
    assert_response :redirect

    survey_response = SurveyResponse.build(student: @student, survey: @survey)
    get survey_response_path(survey_response)
    assert_response :success
    assert_includes response.body, "Latest"
    assert_includes response.body, "←"
  end

  test "admin delete creates notification" do
    sign_in @student_user
    answers = {}
    @survey.questions.limit(1).each { |q| answers[q.id.to_s] = "A1" }
    post submit_survey_path(@survey), params: { answers: answers }
    assert_response :redirect

    sign_in @admin_user
    survey_response = SurveyResponse.build(student: @student, survey: @survey)

    assert_difference "Notification.count", 1 do
      delete survey_response_path(survey_response)
    end

    assert_redirected_to student_records_path
  end
end
