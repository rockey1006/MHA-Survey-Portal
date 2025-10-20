require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in @admin
    @feedback = feedbacks(:advisor_feedback)
    @student = students(:student)
    @advisor = advisors(:advisor)
    @category = categories(:clinical_skills)
  end

  test "index renders successfully" do
    get feedbacks_path
    assert_response :success
    assert_includes response.body, "Feedbacks"
  end

  test "show displays existing feedback" do
    get feedback_path(@feedback)
    assert_response :success
    assert_includes response.body, @feedback.comments
  end

  test "new renders form" do
    get new_feedback_path
    assert_response :success
    assert_select "form"
  end

  test "create with invalid data re-renders form" do
    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: { feedback: { comments: "Missing associations" } }
    end

    assert_response :unprocessable_entity
    assert_select "div", /error/i
  end

  test "create persists feedback with valid data" do
    params = {
      feedback: {
        student_id: @student.student_id,
        advisor_id: @advisor.advisor_id,
        category_id: @category.id,
        survey_id: surveys(:spring_2025).id,
        average_score: 3.7,
        comments: "Thoughtful feedback"
      }
    }

    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: params
    end

    feedback = Feedback.order(:created_at).last
    assert_redirected_to feedback_path(feedback)
    follow_redirect!
    assert_includes response.body, "Feedback was successfully created"
  end

  test "destroy removes feedback" do
    assert_difference "Feedback.count", -1 do
      delete feedback_path(@feedback)
    end

    assert_redirected_to feedbacks_path
    follow_redirect!
    assert_includes response.body, "Feedback was successfully destroyed"
  end
end
