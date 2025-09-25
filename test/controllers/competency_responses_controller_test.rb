require "test_helper"

class CompetencyResponsesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  setup do
    @competency_response = competency_responses(:one)
    @admin = admins(:one)
    sign_in @admin
  end

  test "should get index" do
    get competency_responses_url
    assert_response :success
  end

  test "should get new" do
    get new_competency_response_url
    assert_response :success
  end

  test "should create competency_response" do
    assert_difference("CompetencyResponse.count") do
      post competency_responses_url, params: { competency_response: { competency_id: @competency_response.competency_id, competencyresponse_id: @competency_response.competencyresponse_id, surveyresponse_id: @competency_response.surveyresponse_id } }
    end

    assert_redirected_to competency_response_url(CompetencyResponse.last)
  end

  test "should show competency_response" do
    get competency_response_url(@competency_response)
    assert_response :success
  end

  test "should get edit" do
    get edit_competency_response_url(@competency_response)
    assert_response :success
  end

  test "should update competency_response" do
    patch competency_response_url(@competency_response), params: { competency_response: { competency_id: @competency_response.competency_id, competencyresponse_id: @competency_response.competencyresponse_id, surveyresponse_id: @competency_response.surveyresponse_id } }
    assert_redirected_to competency_response_url(@competency_response)
  end

  test "should destroy competency_response" do
    assert_difference("CompetencyResponse.count", -1) do
      delete competency_response_url(@competency_response)
    end

    assert_redirected_to competency_responses_url
  end
end
