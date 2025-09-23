require "test_helper"

class QuestionResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @question_response = question_responses(:one)
  end

  test "should get index" do
    get question_responses_url
    assert_response :success
  end

  test "should get new" do
    get new_question_response_url
    assert_response :success
  end

  test "should create question_response" do
    assert_difference("QuestionResponse.count") do
      post question_responses_url, params: { question_response: { answer: @question_response.answer, competencyresponse_id: @question_response.competencyresponse_id, question_id: @question_response.question_id, questionresponse_id: @question_response.questionresponse_id } }
    end

    assert_redirected_to question_response_url(QuestionResponse.last)
  end

  test "should show question_response" do
    get question_response_url(@question_response)
    assert_response :success
  end

  test "should get edit" do
    get edit_question_response_url(@question_response)
    assert_response :success
  end

  test "should update question_response" do
    patch question_response_url(@question_response), params: { question_response: { answer: @question_response.answer, competencyresponse_id: @question_response.competencyresponse_id, question_id: @question_response.question_id, questionresponse_id: @question_response.questionresponse_id } }
    assert_redirected_to question_response_url(@question_response)
  end

  test "should destroy question_response" do
    assert_difference("QuestionResponse.count", -1) do
      delete question_response_url(@question_response)
    end

    assert_redirected_to question_responses_url
  end
end
