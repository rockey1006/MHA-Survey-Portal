require "test_helper"

class CompetenciesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @competency = competencies(:one)
    @admin = admins(:one)
    sign_in @admin
  end

  test "should get index" do
    get competencies_url
    assert_response :success
  end

  test "should get new" do
    get new_competency_url
    assert_response :success
  end

  test "should create competency" do
    assert_difference("Competency.count") do
      post competencies_url, params: { competency: { competency_id: @competency.competency_id, description: @competency.description, name: @competency.name, survey_id: @competency.survey_id } }
    end

    assert_redirected_to competency_url(Competency.last)
  end

  test "should show competency" do
    get competency_url(@competency)
    assert_response :success
  end

  test "should get edit" do
    get edit_competency_url(@competency)
    assert_response :success
  end

  test "should update competency" do
    patch competency_url(@competency), params: { competency: { competency_id: @competency.competency_id, description: @competency.description, name: @competency.name, survey_id: @competency.survey_id } }
    assert_redirected_to competency_url(@competency)
  end

  test "should destroy competency" do
    assert_difference("Competency.count", -1) do
      delete competency_url(@competency)
    end

    assert_redirected_to competencies_url
  end
end
