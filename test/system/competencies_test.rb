require "application_system_test_case"

class CompetenciesTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @competency = competencies(:one)
    sign_in admins(:one)
  end

  test "visiting the index" do
    visit competencies_url
    assert_selector "h1", text: "Competencies"
  end

  test "should create competency" do
    visit competencies_url
    click_on "New competency"

    fill_in "Competency", with: @competency.competency_id
    fill_in "Description", with: @competency.description
    fill_in "Name", with: @competency.name
    fill_in "Survey", with: @competency.survey_id
    click_on "Create Competency"

    assert_text "Competency was successfully created"
    click_on "Back"
  end

  test "should update Competency" do
    visit competency_url(@competency)
    click_on "Edit this competency", match: :first

    fill_in "Competency", with: @competency.competency_id
    fill_in "Description", with: @competency.description
    fill_in "Name", with: @competency.name
    fill_in "Survey", with: @competency.survey_id
    click_on "Update Competency"

    assert_text "Competency was successfully updated"
    click_on "Back"
  end

  test "should destroy Competency" do
    visit competency_url(@competency)
    click_on "Destroy this competency", match: :first

    assert_text "Competency was successfully destroyed"
  end
end
