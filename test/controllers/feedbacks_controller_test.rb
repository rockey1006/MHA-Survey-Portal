require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @adv_user = User.create!(email: "adv2@example.com", name: "Adv2", role: "advisor")
    @advisor = @adv_user.advisor_profile

    @student_user = User.create!(email: "stu2@example.com", name: "Stu2", role: "student")
    @student = @student_user.student_profile

    @survey = Survey.new(title: "Survey X", semester: "Fall")
    cat_a = @survey.categories.build(name: "Cat A")
    cat_a.questions.build(question_text: "Q A1", question_order: 1, question_type: "short_answer")
    cat_b = @survey.categories.build(name: "Cat B")
    cat_b.questions.build(question_text: "Q B1", question_order: 1, question_type: "short_answer")
    @survey.save!
    @cat1, @cat2 = @survey.categories

    sign_in @adv_user
  end

  test "batch create creates feedback records and redirects" do
    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        @cat1.id.to_s => { average_score: "4", comments: "Good" },
        @cat2.id.to_s => { average_score: "3", comments: "Ok" }
      }
    }

    assert_difference -> { Feedback.count }, 2 do
      post feedbacks_path, params: params
    end

    assert_response :redirect
    assert_redirected_to student_records_path
    assert_equal 2, Feedback.where(student_id: @student.student_id, survey_id: @survey.id).count
  end
end
