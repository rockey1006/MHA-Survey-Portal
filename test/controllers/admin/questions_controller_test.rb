require "test_helper"

class Admin::QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @category = categories(:clinical_skills)
    sign_in @admin
  end

  test "index accessible to admin" do
    get questions_path
    assert_response :success
  end

  test "create question" do
    params = { question: { category_id: @category.id, question_text: "New Q", question_type: "short_answer", question_order: 99 } }
    assert_difference "Question.count", 1 do
      post questions_path, params: params
    end
    # Controller may redirect to the created question's show page
    assert_redirected_to question_path(Question.order(:created_at).last)
  end

  test "destroy question" do
    q = questions(:fall_q1)
    assert_difference "Question.count", -1 do
      delete question_path(q)
    end
    assert_redirected_to questions_path
  end
end
