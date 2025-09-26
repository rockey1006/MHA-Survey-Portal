require "application_system_test_case"

class FeedbacksTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @feedback = feedbacks(:one)
    sign_in admins(:one)
  end

  test "visiting the index" do
    visit feedbacks_url
    assert_selector "h1", text: "Feedbacks"
  end

  test "should create feedback" do
    visit feedbacks_url
    click_on "New feedback"

    fill_in "Advisor", with: @feedback.advisor_id
    fill_in "Comments", with: @feedback.comments
    fill_in "Competency", with: @feedback.competency_id
    fill_in "Feedback", with: @feedback.feedback_id
    fill_in "Rating", with: @feedback.rating
    click_on "Create Feedback"

    assert_text "Feedback was successfully created"
    click_on "Back"
  end

  test "should update Feedback" do
    visit feedback_url(@feedback)
    click_on "Edit this feedback", match: :first

    fill_in "Advisor", with: @feedback.advisor_id
    fill_in "Comments", with: @feedback.comments
    fill_in "Competency", with: @feedback.competency_id
    fill_in "Feedback", with: @feedback.feedback_id
    fill_in "Rating", with: @feedback.rating
    click_on "Update Feedback"

    assert_text "Feedback was successfully updated"
    click_on "Back"
  end

  test "should destroy Feedback" do
    visit feedback_url(@feedback)
    click_on "Destroy this feedback", match: :first

    assert_text "Feedback was successfully destroyed"
  end
end
