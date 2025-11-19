require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @adv_user = users(:advisor)
    @advisor = @adv_user.advisor_profile

    @student_user = users(:student)
    @student = students(:student) || Student.first

    @survey = (defined?(surveys) && surveys(:fall_2025) rescue nil)
    unless @survey
      @survey = Survey.create!(title: "Survey X", semester: "Fall")
      c1 = @survey.categories.create!(name: "Cat A")
      c1.questions.create!(question_text: "Q A1", question_order: 1, question_type: "short_answer")
      c2 = @survey.categories.create!(name: "Cat B")
      c2.questions.create!(question_text: "Q B1", question_order: 1, question_type: "short_answer")
    end

    # Ensure survey has at least two categories (fixtures may not include them)
    if @survey.categories.count < 2
      (2 - @survey.categories.count).times do |i|
        c = @survey.categories.create!(name: "Cat #{i + 1}")
        c.questions.create!(question_text: "Q #{i + 1}", question_order: i + 1, question_type: "short_answer")
      end
      @survey.reload
    end
    @cat1, @cat2 = @survey.categories.order(:id).limit(2)

    sign_in @adv_user
  end

  test "batch create creates feedback records and redirects" do
    # Controller now expects ratings keyed by question id (per-question feedback)
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Auto Q1", question_order: 1, question_type: "short_answer")
    q2 = @cat2.questions.first || @cat2.questions.create!(question_text: "Auto Q2", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "4", comments: "Good" },
        q2.id.to_s => { average_score: "3", comments: "Ok" }
      }
    }

    before_count = Feedback.where(student_id: @student.student_id, survey_id: @survey.id).count
    post feedbacks_path, params: params

    assert_response :redirect
    assert_redirected_to student_records_path
    after_count = Feedback.where(student_id: @student.student_id, survey_id: @survey.id).count
    assert_equal before_count + 2, after_count
  end
end
