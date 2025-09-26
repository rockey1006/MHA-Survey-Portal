require "application_system_test_case"

class CompetencyResponsesTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @competency_response = competency_responses(:one)
    sign_in admins(:one)
  end

  test "visiting the index" do
    visit competency_responses_url
    assert_selector "h1", text: "Competency responses"
  end

  test "should create competency response" do
    visit competency_responses_url
    click_on "New competency response"

    fill_in "Competency", with: @competency_response.competency_id
    fill_in "Competencyresponse", with: @competency_response.competencyresponse_id
    fill_in "Surveyresponse", with: @competency_response.surveyresponse_id
    click_on "Create Competency response"

    assert_text "Competency response was successfully created"
    click_on "Back"
  end

  test "should update Competency response" do
    visit competency_response_url(@competency_response)
    click_on "Edit this competency response", match: :first

    fill_in "Competency", with: @competency_response.competency_id
    fill_in "Competencyresponse", with: @competency_response.competencyresponse_id
    fill_in "Surveyresponse", with: @competency_response.surveyresponse_id
    click_on "Update Competency response"

    assert_text "Competency response was successfully updated"
    click_on "Back"
  end

  test "should destroy Competency response" do
    visit competency_response_url(@competency_response)
    click_on "Destroy this competency response", match: :first

    assert_text "Competency response was successfully destroyed"
  end
end
