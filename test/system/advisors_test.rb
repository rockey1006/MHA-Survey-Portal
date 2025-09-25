require "application_system_test_case"

class AdvisorsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  
  setup do
    @advisor = advisors(:one)
    sign_in admins(:one)
  end

  test "visiting the index" do
    visit advisors_url
    assert_selector "h1", text: "Advisors"
  end

  test "should create advisor" do
    visit advisors_url
    click_on "New advisor"

    fill_in "Advisor", with: @advisor.advisor_id
    fill_in "Email", with: @advisor.email
    fill_in "Name", with: @advisor.name
    click_on "Create Advisor"

    assert_text "Advisor was successfully created"
    click_on "Back"
  end

  test "should update Advisor" do
    visit advisor_url(@advisor)
    click_on "Edit this advisor", match: :first

    fill_in "Advisor", with: @advisor.advisor_id
    fill_in "Email", with: @advisor.email
    fill_in "Name", with: @advisor.name
    click_on "Update Advisor"

    assert_text "Advisor was successfully updated"
    click_on "Back"
  end

  test "should destroy Advisor" do
    visit advisor_url(@advisor)
    click_on "Destroy this advisor", match: :first

    assert_text "Advisor was successfully destroyed"
  end
end
