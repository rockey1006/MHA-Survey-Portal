require "test_helper"

class Admin::QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in @admin
    @category = categories(:clinical_skills)
    @question = questions(:fall_q1)
  end

  test "index loads questions" do
    get admin_questions_path
    assert_response :success
    assert_includes response.body, @question.question_text
  end

  test "new initializes question" do
    get new_admin_question_path
    assert_response :success
    assert_select "form"
  end

  test "create saves new question" do
    params = {
      question: {
        question: "New prompt",
        question_type: "short_answer",
        question_order: Question.maximum(:question_order).to_i + 1,
        category_id: @category.id
      }
    }

    assert_difference "Question.count", 1 do
      post admin_questions_path, params: params
    end

    assert_redirected_to admin_questions_path
    assert_equal "Question created successfully.", flash[:notice]
    follow_redirect!
    assert_includes response.body, "Question created successfully."
  end

  test "create renders form on invalid data" do
    assert_no_difference "Question.count" do
      post admin_questions_path, params: { question: { question: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "create accepts legacy category_ids when category_id missing" do
    params = {
      question: {
        question_text: "New prompt via category_ids",
        question_type: "short_answer",
        question_order: Question.maximum(:question_order).to_i + 1,
        category_ids: [ "", @category.id.to_s ]
      }
    }

    assert_difference "Question.count", 1 do
      post admin_questions_path, params: params
    end

    created = Question.order(:id).last
    assert_equal @category.id, created.category_id
  end

  test "update saves changes" do
    patch admin_question_path(@question), params: {
      question: {
        question: "Updated text",
        question_type: @question.question_type,
        question_order: @question.question_order,
        category_id: @category.id
      }
    }

    assert_redirected_to admin_questions_path
  assert_equal "Question updated successfully.", flash[:notice]
    assert_equal "Updated text", @question.reload.question_text
  end

  test "update renders edit on invalid data" do
    patch admin_question_path(@question), params: {
      question: {
        question_text: "",
        question_type: @question.question_type,
        question_order: @question.question_order,
        category_id: @category.id
      }
    }

    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "destroy removes question" do
    question = Question.create!(
      question_text: "Temp question",
      question_type: "short_answer",
      question_order: Question.maximum(:question_order).to_i + 1,
      category: @category
    )

    assert_difference "Question.count", -1 do
      delete admin_question_path(question)
    end

    assert_redirected_to admin_questions_path
  end
end
