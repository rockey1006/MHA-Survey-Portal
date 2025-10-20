require "test_helper"
require "securerandom"

class QuestionResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in @admin

    @student = students(:student)
    @advisor = advisors(:advisor)
    @category = categories(:clinical_skills)
    @question = @category.questions.create!(
      question_text: "Temp question #{SecureRandom.hex(4)}",
      question_order: Question.maximum(:question_order).to_i + 1,
      question_type: "short_answer"
    )

    @question_response = QuestionResponse.create!(
      student: @student,
      advisor: @advisor,
      question: @question,
      answer: "Initial answer"
    )
  end

  test "index lists responses" do
    get question_responses_path
    assert_response :success
    assert_includes response.body, "Initial answer"
  end

  test "show displays selected response" do
    get question_response_path(@question_response)
    assert_response :success
    assert_includes response.body, @question_response.answer
  end

  test "new renders creation form" do
    get new_question_response_path
    assert_response :success
    assert_select "form"
  end

  test "create with invalid data re-renders form" do
    assert_no_difference "QuestionResponse.count" do
      post question_responses_path, params: { question_response: { answer: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "create persists response" do
    new_question = @category.questions.create!(
      question_text: "Additional #{SecureRandom.hex(4)}",
      question_order: Question.maximum(:question_order).to_i + 1,
      question_type: "short_answer"
    )

    params = {
      question_response: {
        student_id: @student.student_id,
        advisor_id: @advisor.advisor_id,
        question_id: new_question.id,
        answer: "New answer"
      }
    }

    assert_difference "QuestionResponse.count", 1 do
      post question_responses_path, params: params
    end

    response_record = QuestionResponse.order(:created_at).last
    assert_redirected_to question_response_path(response_record)
    follow_redirect!
    assert_includes response.body, "Question response was successfully created"
  end

  test "update modifies answer" do
    patch question_response_path(@question_response), params: {
      question_response: { answer: "Updated answer" }
    }

    assert_redirected_to question_response_path(@question_response)
    assert_equal "Updated answer", @question_response.reload.answer
  end

  test "destroy removes response" do
    assert_difference "QuestionResponse.count", -1 do
      delete question_response_path(@question_response)
    end

    assert_redirected_to question_responses_path
  end
end
