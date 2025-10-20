require "test_helper"

class FeedbacksControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
  @adv_user = User.create!(email: "adv2@example.com", name: "Adv2", role: "advisor")
  @advisor = @adv_user.advisor_profile
  @student_user = User.create!(email: "stu2@example.com", name: "Stu2", role: "student")
  @student = @student_user.student_profile
  @survey = Survey.new(title: "Survey X", semester: "Fall")
  c1 = @survey.categories.build(name: "Cat A")
  c1.questions.build(question_text: "Q A1", question_order: 1, question_type: "short_answer")
  c2 = @survey.categories.build(name: "Cat B")
  c2.questions.build(question_text: "Q B1", question_order: 1, question_type: "short_answer")
  @survey.save!
  @cat1, @cat2 = @survey.categories

    sign_in @adv_user
  end

  test "batch create creates feedback records and redirects" do
    post :create, params: { survey_id: @survey.id, student_id: @student.id, ratings: { @cat1.id.to_s => { average_score: "4", comments: "Good" }, @cat2.id.to_s => { average_score: "3", comments: "Ok" } } }
    assert_response :redirect
    assert_redirected_to student_records_path
    assert_equal 2, Feedback.where(student_id: @student.student_id, survey_id: @survey.id).count
  end
end
