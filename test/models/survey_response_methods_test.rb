require "test_helper"

class SurveyResponseMethodsTest < ActiveSupport::TestCase
  test "status transitions from not_started to submitted" do
    student = students(:student)
    survey = surveys(:fall_2025)

    # Ensure no student questions exist initially
    StudentQuestion.where(student_id: student.student_id, question_id: survey.questions.select(:id)).delete_all

    sr = SurveyResponse.new(student: student, survey: survey)
    assert_equal :not_started, sr.status

    # create answers for all survey questions
    survey.questions.each do |q|
      StudentQuestion.create!(student_id: student.student_id, question: q, response_value: "Ans")
    end

    sr2 = SurveyResponse.new(student: student, survey: survey)
    assert_equal :submitted, sr2.status
  end

  test "answered_count and total_questions reflect DB" do
    student = students(:student)
    survey = surveys(:fall_2025)
    StudentQuestion.where(student_id: student.student_id, question_id: survey.questions.select(:id)).delete_all

    # add single answer
    q = survey.questions.first
    StudentQuestion.create!(student_id: student.student_id, question: q, response_value: "Hello")

    sr = SurveyResponse.new(student: student, survey: survey)
    assert_equal 1, sr.answered_count
    assert_equal survey.questions.count, sr.total_questions
  end

  test "evidence_history_by_category groups evidence responses" do
    student = students(:student)
    survey = surveys(:fall_2025)
    # create an evidence question fixture dynamically if none exists
    ev_q = survey.questions.detect { |qq| qq.question_type == "evidence" }
    unless ev_q
      cat = survey.categories.first
      ev_q = Question.create!(category: cat, question_text: "Evidence question", question_order: 999, question_type: "evidence", is_required: false)
    end

    sq = StudentQuestion.create!(student_id: student.student_id, question: ev_q, response_value: "https://drive.google.com/file/d/1")
    sr = SurveyResponse.new(student: student, survey: survey)
    grouped = sr.evidence_history_by_category
    assert_kind_of Hash, grouped
    # ensure category id present
    assert_includes grouped.keys, ev_q.category.id
  end

  test "completion_date returns updated_at from responses" do
    student = students(:student)
    survey = surveys(:fall_2025)
  q1 = survey.questions[0]
  q2 = survey.questions[1] || Question.create!(category: survey.categories.first, question_text: "Temp", question_order: 999, question_type: "short_answer", is_required: false)
  StudentQuestion.create!(student_id: student.student_id, question: q1, response_value: "X", updated_at: 2.days.ago)
  StudentQuestion.create!(student_id: student.student_id, question: q2, response_value: "Y", updated_at: 1.day.ago)
    sr = SurveyResponse.new(student: student, survey: survey)
    assert_in_delta 1.day.ago.to_i, sr.completion_date.to_i, 5
  end
end
