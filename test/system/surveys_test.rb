require "application_system_test_case"

class SurveysTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  
  setup do
    @survey = surveys(:one)
    sign_in admins(:one)
  end

  test "visiting the index" do
    visit surveys_url
    assert_selector "h1", text: "Surveys"
  end

  test "should create survey" do
    visit surveys_url
    click_on "New survey"
    fill_in "Title", with: @survey.title
    fill_in "Semester", with: @survey.semester
    fill_in "Approval date", with: @survey.approval_date
    fill_in "Assigned date", with: @survey.assigned_date
    fill_in "Completion date", with: @survey.completion_date
    fill_in "Survey", with: @survey.survey_id
    click_on "Create Survey"

    assert_text "Survey was successfully created"
    click_on "Back"
  end

  test "should update Survey" do
    visit survey_url(@survey)
    click_on "Edit this survey", match: :first
    fill_in "Title", with: @survey.title
    fill_in "Semester", with: @survey.semester
    fill_in "Approval date", with: @survey.approval_date
    fill_in "Assigned date", with: @survey.assigned_date
    fill_in "Completion date", with: @survey.completion_date
    fill_in "Survey", with: @survey.survey_id
    click_on "Update Survey"

    assert_text "Survey was successfully updated"
    click_on "Back"
  end

  test "should destroy Survey" do
    visit survey_url(@survey)
    click_on "Destroy this survey", match: :first

    assert_text "Survey was successfully destroyed"
  end
end
