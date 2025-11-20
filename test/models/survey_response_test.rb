require "test_helper"

class SurveyResponseTest < ActiveSupport::TestCase
  test "answers returns map of question id to answer when question_responses provided" do
    student = students(:student)
    survey = surveys(:fall_2025)
    sr = SurveyResponse.new(student: student, survey: survey)

    # provide a fake question_responses array for the PORO
    qr1 = OpenStruct.new(question_id: questions(:fall_q1).id, answer: "Yes")
    qr2 = OpenStruct.new(question_id: questions(:fall_q1).id + 1, answer: "No")
    sr.instance_variable_set(:@question_responses, [ qr1, qr2 ])

    map = sr.answers
    assert_kind_of Hash, map
    assert_equal "Yes", map[questions(:fall_q1).id]
  end

  test "id composes student id and survey id" do
    student = students(:student)
    survey = surveys(:fall_2025)
    sr = SurveyResponse.new(student: student, survey: survey)
    assert_match /#{student.student_id}-#{survey.id}/, sr.id
  end

  test "build creates a SurveyResponse and associates records" do
    survey = surveys(:fall_2025)
    student = students(:student)
    sr = SurveyResponse.build(student: student, survey: survey)
    # SurveyResponse is a PORO (ActiveModel), not persisted ActiveRecord
    assert_instance_of SurveyResponse, sr
    assert_equal "#{student.student_id}-#{survey.id}", sr.id
    assert_equal "#{student.student_id}-#{survey.id}", sr.to_param
  end
  setup do
    @student = students(:student)
    @advisor = advisors(:advisor)
    @student.update!(advisor: @advisor)

    @survey = surveys(:fall_2025)
    @question = questions(:fall_q1)
    StudentQuestion.where(student_id: @student.student_id).delete_all
  end

  test "answers returns student responses keyed by question id" do
    StudentQuestion.create!(student_id: @student.student_id, advisor: @advisor, question: @question, response_value: "Very satisfied")

    survey_response = SurveyResponse.build(student: @student, survey: @survey)

    assert_equal({ @question.id => "Very satisfied" }, survey_response.answers)
  end

  test "question responses scope to survey" do
    other_survey = Survey.new(title: "Other", semester: "Fall 2025")
    other_category = other_survey.categories.build(name: "Other", description: "Other category")
    other_question = other_category.questions.build(
      question_text: "Other?",
      question_order: 2,
      question_type: "short_answer",
      is_required: false
    )
    other_survey.save!

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
