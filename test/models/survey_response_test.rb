require "test_helper"

class SurveyResponseTest < ActiveSupport::TestCase
  setup do
    @student = students(:student)
    @advisor = advisors(:advisor)
    @student.update!(advisor: @advisor)

    @survey = surveys(:fall_2025)
    @question = questions(:fall_q1)
    SurveyQuestion.find_or_create_by!(survey: @survey, question: @question)
  end

  test "answers returns student responses keyed by question id" do
    StudentQuestion.create!(student_id: @student.student_id, advisor: @advisor, question: @question, response_value: "Very satisfied")

    survey_response = SurveyResponse.build(student: @student, survey: @survey)

    assert_equal({ @question.id => "Very satisfied" }, survey_response.answers)
  end

  test "question responses scope to survey" do
    other_survey = Survey.create!(title: "Other", semester: "Fall 2025")
    other_question = Question.create!(question: "Other?", question_order: 2, question_type: "short_answer", required: false)
    SurveyQuestion.create!(survey: other_survey, question: other_question)

    StudentQuestion.create!(student_id: @student.student_id, advisor: @advisor, question: @question, response_value: "Very satisfied")
    StudentQuestion.create!(student_id: @student.student_id, advisor: @advisor, question: other_question, response_value: "Different")

    survey_response = SurveyResponse.build(student: @student, survey: @survey)

    question_ids = survey_response.question_responses.pluck(:question_id)
    assert_equal [ @question.id ], question_ids
  end

  test "advisor delegates to student advisor" do
    survey_response = SurveyResponse.build(student: @student, survey: @survey)
    assert_equal @advisor, survey_response.advisor
  end
end
