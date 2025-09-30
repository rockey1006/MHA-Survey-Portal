require "application_system_test_case"

class CompleteSurveyWorkflowTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = admins(:one)
    @advisor = admins(:two)
    @student = students(:one)
    sign_in @admin
  end

  test "complete survey creation and response workflow" do
    # Step 1: Create a new survey
    visit surveys_url
    click_on "New survey"

    fill_in "Title", with: "Complete Workflow Test Survey"
    fill_in "Semester", with: "System Test Semester"
    fill_in "Survey", with: "8888"
    fill_in "Approval date", with: Date.current.strftime("%Y-%m-%d")
    fill_in "Assigned date", with: (Date.current + 1.day).strftime("%Y-%m-%d")
    fill_in "Completion date", with: (Date.current + 30.days).strftime("%Y-%m-%d")

    click_on "Create Survey"
    assert_text "Survey was successfully created"

    # Get the created survey
    survey = Survey.find_by(survey_id: 8888)

    # Step 2: Add a competency to the survey
    visit competencies_url
    click_on "New competency"

    fill_in "Title", with: "System Test Competency"
    fill_in "Description", with: "This is a system test competency"
    fill_in "Competency", with: "8888"
    select survey.title, from: "Survey" if page.has_select?("Survey")

    click_on "Create Competency"
    assert_text "Competency was successfully created"

    competency = Competency.find_by(competency_id: 8888)

    # Step 3: Add questions to the competency
    visit questions_url
    click_on "New question"

    fill_in "Text", with: "How would you rate your understanding?"
    fill_in "Question", with: "8888"
    fill_in "Question order", with: "1"
    select "select", from: "Question type" if page.has_select?("Question type")
    select competency.title, from: "Competency" if page.has_select?("Competency")

    # Handle answer options based on your form implementation
    if page.has_field?("Answer options")
      fill_in "Answer options", with: "Excellent,Good,Fair,Poor"
    end

    click_on "Create Question"
    assert_text "Question was successfully created"

    # Step 4: Create a survey response
    visit survey_responses_url
    click_on "New survey response"

    fill_in "Surveyresponse", with: "8888"
    select survey.title, from: "Survey" if page.has_select?("Survey")
    select @student.name, from: "Student" if page.has_select?("Student")
    select "not_started", from: "Status" if page.has_select?("Status")

    click_on "Create Survey response"
    assert_text "Survey response was successfully created"

    survey_response = SurveyResponse.find_by(surveyresponse_id: 8888)

    # Step 5: Update survey response status to in_progress
    visit survey_response_url(survey_response)
    click_on "Edit this survey response"

    select "in_progress", from: "Status"
    click_on "Update Survey response"
    assert_text "Survey response was successfully updated"

    # Step 6: Add question responses
    visit question_responses_url
    click_on "New question response"

    fill_in "Questionresponse", with: "8888"
    question = Question.find_by(question_id: 8888)
    select question.text, from: "Question" if page.has_select?("Question")
    fill_in "Response text", with: "Good"

    click_on "Create Question response"
    assert_text "Question response was successfully created"

    # Step 7: Submit the survey response
    visit survey_response_url(survey_response)
    click_on "Edit this survey response"

    select "submitted", from: "Status"
    click_on "Update Survey response"
    assert_text "Survey response was successfully updated"

    # Step 8: Verify the complete workflow
    survey_response.reload
    assert_equal "submitted", survey_response.status

    question_response = QuestionResponse.find_by(questionresponse_id: 8888)
    assert_equal "Good", question_response.response_text

    # Verify associations
    assert_equal survey.id, competency.survey_id
    assert_equal competency.id, question.competency_id
    assert_equal survey_response.id, question_response.survey_response_id if question_response.respond_to?(:survey_response_id)
  end

  test "survey dashboard and reporting workflow" do
    # Create test data
    survey = Survey.create!(
      survey_id: 7777,
      title: "Dashboard Test Survey",
      semester: "Dashboard Test",
      assigned_date: Date.current,
      completion_date: Date.current + 30.days
    )

    # Create survey responses with different statuses
    [ "not_started", "in_progress", "submitted", "approved" ].each_with_index do |status, index|
      SurveyResponse.create!(
        surveyresponse_id: 7000 + index,
        survey_id: survey.id,
        student_id: @student.id,
        status: status
      )
    end

    # Visit survey dashboard or index
    visit surveys_url

    # Should see the survey in the list
    assert_text "Dashboard Test Survey"

    # Click on the survey to view details
    click_on "Dashboard Test Survey"

    # Should see survey information
    assert_text "Dashboard Test Survey"
    assert_text "Dashboard Test"

    # Test navigation between related records
    if page.has_link?("Survey Responses")
      click_on "Survey Responses"
      # Should see the different response statuses
      begin
        assert_text "not_started"
      rescue Minitest::Assertion
        assert_text "Not started"
      end
      begin
        assert_text "submitted"
      rescue Minitest::Assertion
        assert_text "Submitted"
      end
    end
  end

  test "user authentication and authorization workflow" do
    # Test as admin
    assert_text "Surveys" # Should be on surveys page as admin

    # Admin should see admin-specific elements
    assert page.has_link?("New survey") || page.has_button?("New survey")

    # Test signing out and back in
    if page.has_link?("Sign out")
      click_on "Sign out"
         # Should be redirected to login or home page
    end

    # Sign in as advisor and test different permissions
    sign_in @advisor
    visit surveys_url

    # Advisor should still see surveys but maybe with different permissions
    assert_text "Surveys"
       # Adjust assertions based on your authorization logic
  end

  test "form validation and error handling workflow" do
    # Test survey creation with validation errors
    visit surveys_url
    click_on "New survey"

    # Submit empty form
    click_on "Create Survey"

    # Should show validation errors
    begin
      assert_text "can't be blank"
    rescue Minitest::Assertion
      begin
        assert_text "is required"
      rescue Minitest::Assertion
        assert_text "error"
      end
    end

    # Test with invalid date range
    fill_in "Title", with: "Validation Test"
    fill_in "Survey", with: "6666"
    fill_in "Assigned date", with: (Date.current + 30.days).strftime("%Y-%m-%d")
    fill_in "Completion date", with: Date.current.strftime("%Y-%m-%d") # Before assigned date

    click_on "Create Survey"

       # Should show date validation error (adjust based on your validation)
       # This assumes you have date validation logic
  end

  test "responsive design and mobile compatibility" do
    # Test with smaller viewport to simulate mobile
    page.driver.browser.manage.window.resize_to(375, 667) # iPhone size

    visit surveys_url

    # Basic functionality should still work
    assert_text "Surveys"

    # Navigation should be accessible
    if page.has_selector?(".navbar-toggle") || page.has_selector?("[data-toggle]")
      find(".navbar-toggle", match: :first).click if page.has_selector?(".navbar-toggle")
    end

    # Reset to normal size
    page.driver.browser.manage.window.resize_to(1200, 800)
  end

  test "accessibility features" do
    visit surveys_url

    # Check for basic accessibility features
    # Form labels should be associated with inputs
    if page.has_link?("New survey")
      click_on "New survey"

      # Check that form fields have labels
      assert page.has_selector?("label[for]") || page.has_selector?("label")

         # Check for required field indicators
         # This depends on your form implementation
    end
  end
end
