require "application_system_test_case"

class QuestionsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @question = questions(:one)
    sign_in admins(:one)
  end

  test "visiting the index" do
    visit questions_url
    assert_selector "h1", text: "Questions"
  end

  test "should create question" do
    visit questions_url
    click_on "New question"

    fill_in "Competency", with: @question.competency_id
    fill_in "Question", with: @question.question
    fill_in "Question order", with: @question.question_order
    fill_in "Question type", with: @question.question_type
    fill_in "Answer options", with: @question.answer_options.join(", ")
    click_on "Create Question"

    assert_text "Question was successfully created"
    click_on "Back"
  end

  test "should update Question" do
    visit question_url(@question)
    click_on "Edit this question", match: :first

    fill_in "Competency", with: @question.competency_id
    fill_in "Question", with: @question.question
    fill_in "Question order", with: @question.question_order
    fill_in "Question type", with: @question.question_type
    fill_in "Answer options", with: @question.answer_options.join(", ")
    click_on "Update Question"

    assert_text "Question was successfully updated"
    click_on "Back"
  end

  test "should destroy Question" do
    visit question_url(@question)
    click_on "Destroy this question", match: :first

    assert_text "Question was successfully destroyed"
  end
end
