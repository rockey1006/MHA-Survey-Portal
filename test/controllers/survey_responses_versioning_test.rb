require "test_helper"

class SurveyResponsesVersioningTest < ActionDispatch::IntegrationTest
  setup do
    @student_user = users(:student)
    @admin_user = users(:admin)
    @student = students(:student)
    @survey = surveys(:fall_2025)
  end

  test "admin edit creates a new version and older versions remain viewable" do
    question = @survey.questions.order(:id).first
    assert question, "Expected survey to have at least one question"

    sign_in @student_user

    # Create a baseline version.
    post submit_survey_path(@survey), params: { answers: { question.id.to_s => "A1" } }
    assert_response :redirect

    versions_after_submit = SurveyResponseVersion
                             .for_pair(student_id: @student.student_id, survey_id: @survey.id)
                             .chronological
    assert_equal 1, versions_after_submit.size
    assert_equal "submitted", versions_after_submit.last.event
    assert_equal "A1", versions_after_submit.last.answers[question.id.to_s]

    # Admin edit should create a new "admin_edited" version.
    sign_in @admin_user
    survey_response = SurveyResponse.build(student: @student, survey: @survey)

    assert_difference "SurveyResponseVersion.count", 1 do
      patch survey_response_path(survey_response), params: { answers: { question.id.to_s => "A_ADMIN" } }
    end
    assert_response :redirect

    versions_after_admin = SurveyResponseVersion
                            .for_pair(student_id: @student.student_id, survey_id: @survey.id)
                            .chronological
    assert_equal 2, versions_after_admin.size
    assert_equal "admin_edited", versions_after_admin.last.event
    assert_equal "A_ADMIN", versions_after_admin.last.answers[question.id.to_s]

    # Latest renders.
    get survey_response_path(survey_response)
    assert_response :success

    # Prior version renders via version_id.
    get survey_response_path(survey_response, version_id: versions_after_admin.first.id)
    assert_response :success
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
    assert_includes response.body, "Version"
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
