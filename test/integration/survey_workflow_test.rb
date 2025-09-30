require "test_helper"

class SurveyWorkflowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @admin = admins(:one)
    @advisor = admins(:two)
    @student = students(:one)
    @survey = surveys(:one)
  end

  test "admin can create complete survey with competencies and questions" do
    sign_in @admin

    # Create a new survey
    post surveys_path, params: {
      survey: {
        survey_id: 999,
        title: "Integration Test Survey",
        semester: "Fall 2024",
        assigned_date: Date.current,
        completion_date: Date.current + 30.days,
        approval_date: Date.current - 1.day
      }
    }

    survey = Survey.last
    assert_redirected_to survey_path(survey)

    # Add competency to the survey
    post competencies_path, params: {
      competency: {
        competency_id: 999,
        name: "Test Competency",
        description: "Integration test competency",
        survey_id: survey.id
      }
    }

    competency = Competency.last
    assert_redirected_to competency_path(competency)

    # Add questions to the competency
    post questions_path, params: {
      question: {
        question_id: 999,
        text: "How do you rate your skills?",
        question_type: "select",
        question_order: 1,
        answer_options: [ "Excellent", "Good", "Fair", "Poor" ],
        competency_id: competency.id
      }
    }

    question = Question.last
    assert_redirected_to question_path(question)

    # Verify the complete workflow
    assert_equal survey.id, competency.survey_id
    assert_equal competency.id, question.competency_id
    assert_equal "select", question.question_type
    assert_includes question.answer_options, "Excellent"
  end

  test "student survey response workflow" do
    sign_in @admin # Admin creates survey response for student

    # Create a survey response for the student
    post survey_responses_path, params: {
      survey_response: {
        surveyresponse_id: 999,
        student_id: @student.id,
        survey_id: @survey.id,
        status: "not_started"
      }
    }

    survey_response = SurveyResponse.last
    assert survey_response.status_not_started?

    # Update status to in_progress
    patch survey_response_path(survey_response), params: {
      survey_response: {
        status: "in_progress"
      }
    }

    survey_response.reload
    assert survey_response.status_in_progress?

    # Add question responses
    question = questions(:one)
    post question_responses_path, params: {
      question_response: {
        questionresponse_id: 999,
        question_id: question.id,
        answer: "Excellent"
      }
    }

    question_response = QuestionResponse.last
    assert_equal "Excellent", question_response.answer
    assert_equal question.id, question_response.question_id

    # Submit the survey
    patch survey_response_path(survey_response), params: {
      survey_response: {
        status: "submitted"
      }
    }

    survey_response.reload
    assert survey_response.status_submitted?
  end

  test "advisor review and approval workflow" do
    sign_in @admin

    # Create a submitted survey response
    survey_response = SurveyResponse.create!(
      surveyresponse_id: 998,
      student_id: @student.id,
      survey_id: @survey.id,
      advisor_id: @advisor.id,
      status: "submitted"
    )

    # Advisor reviews and changes status to under_review
    patch survey_response_path(survey_response), params: {
      survey_response: {
        status: "under_review"
      }
    }

    survey_response.reload
    assert survey_response.status_under_review?

    # Advisor approves the survey
    patch survey_response_path(survey_response), params: {
      survey_response: {
        status: "approved"
      }
    }

    survey_response.reload
    assert survey_response.status_approved?
  end

  test "survey data integrity throughout workflow" do
    sign_in @admin

    # Create survey with competencies and questions
    survey = Survey.create!(
      survey_id: 997,
      title: "Data Integrity Test",
      semester: "Test Semester",
      assigned_date: Date.current,
      completion_date: Date.current + 30.days
    )

    competency = survey.competencies.create!(
      competency_id: 997,
      name: "Test Competency",
      description: "Testing data relationships"
    )

    question = competency.questions.create!(
      question_id: 997,
      question: "Test question?",
      question_type: "text",
      question_order: 1
    )

    # Verify associations work correctly
    assert_equal survey, competency.survey
    assert_equal competency, question.competency
    assert_includes survey.competencies, competency
    assert_includes competency.questions, question
    assert_includes survey.questions, question

    # Test cascade delete
    initial_question_count = Question.count
    initial_competency_count = Competency.count

    survey.destroy

    assert_equal initial_question_count - 1, Question.count
    assert_equal initial_competency_count - 1, Competency.count
  end

  test "scope methods work correctly in workflow" do
    # Test SurveyResponse scopes
    student = @student

    # Create various survey responses
    not_started = SurveyResponse.create!(
      surveyresponse_id: 990,
      student_id: student.id,
      survey_id: @survey.id,
      status: "not_started"
    )

    in_progress = SurveyResponse.create!(
      surveyresponse_id: 991,
      student_id: student.id,
      survey_id: @survey.id,
      status: "in_progress"
    )

    submitted = SurveyResponse.create!(
      surveyresponse_id: 992,
      student_id: student.id,
      survey_id: @survey.id,
      status: "submitted"
    )

    # Test scopes
    pending_responses = SurveyResponse.pending_for_student(student.id)
    completed_responses = SurveyResponse.completed_for_student(student.id)

    assert_includes pending_responses, not_started
    assert_includes pending_responses, in_progress
    assert_not_includes pending_responses, submitted

    assert_includes completed_responses, submitted
    assert_not_includes completed_responses, not_started
    assert_not_includes completed_responses, in_progress
  end
end
