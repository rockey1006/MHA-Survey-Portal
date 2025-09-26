require "application_system_test_case"

class QuestionResponsesTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @question_response = question_responses(:one)
    sign_in admins(:one)
  end

  test "visiting the index" do
    visit question_responses_url
    assert_selector "h1", text: "Question responses"
  end

  test "should create question response" do
    visit question_responses_url
    click_on "New question response"

    fill_in "Answer", with: @question_response.answer
    fill_in "Competencyresponse", with: @question_response.competencyresponse_id
    fill_in "Question", with: @question_response.question_id
    fill_in "Questionresponse", with: @question_response.questionresponse_id
    click_on "Create Question response"

    assert_text "Question response was successfully created"
    click_on "Back"
  end

  test "should update Question response" do
    visit question_response_url(@question_response)
    click_on "Edit this question response", match: :first

    fill_in "Answer", with: @question_response.answer
    fill_in "Competencyresponse", with: @question_response.competencyresponse_id
    fill_in "Question", with: @question_response.question_id
    fill_in "Questionresponse", with: @question_response.questionresponse_id
    click_on "Update Question response"

    assert_text "Question response was successfully updated"
    click_on "Back"
  end

  test "should destroy Question response" do
    visit question_response_url(@question_response)
    click_on "Destroy this question response", match: :first

    assert_text "Question response was successfully destroyed"
  end
end
