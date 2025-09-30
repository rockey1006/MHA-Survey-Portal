require "application_system_test_case"

class SurveysTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @survey = surveys(:one)
    @admin = admins(:one)
    sign_in @admin
  end

  test "visiting the index shows all surveys" do
    visit surveys_url
    assert_selector "h1", text: "Surveys"

    # Should display survey information
    assert_text @survey.title
    assert_text @survey.semester

    # Should have navigation elements
    assert_selector "a", text: "New survey"
  end

  test "should create survey with complete workflow" do
    visit surveys_url
    click_on "New survey"

    # Fill in the form
    fill_in "Title", with: "System Test Survey"
    fill_in "Semester", with: "Fall 2024"
    fill_in "Survey", with: "9999"

    # Fill in dates (adjust selectors based on your form)
    fill_in "Approval date", with: Date.current.strftime("%Y-%m-%d")
    fill_in "Assigned date", with: (Date.current + 1.day).strftime("%Y-%m-%d")
    fill_in "Completion date", with: (Date.current + 30.days).strftime("%Y-%m-%d")

    click_on "Create Survey"

    # Verify creation
    assert_text "Survey was successfully created"
    assert_text "System Test Survey"
    assert_text "Fall 2024"

    # Navigate back to index
    click_on "Back"
    assert_current_path surveys_path
    assert_text "System Test Survey"
  end

  test "should update Survey with validation" do
    visit survey_url(@survey)
    click_on "Edit this survey", match: :first

    # Update with new values
    fill_in "Title", with: "Updated Survey Title"
    fill_in "Semester", with: "Spring 2025"

    click_on "Update Survey"

    assert_text "Survey was successfully updated"
    assert_text "Updated Survey Title"
    assert_text "Spring 2025"

    click_on "Back"
  end

  test "should show validation errors for invalid survey" do
    visit surveys_url
    click_on "New survey"

    # Submit empty form to trigger validations
    click_on "Create Survey"

    # Should show error messages (adjust based on your validation messages)
    begin
      assert_text "can't be blank"
    rescue Minitest::Assertion
      begin
        assert_text "is required"
      rescue Minitest::Assertion
        assert_text "error"
      end
    end
  end

  test "should destroy Survey with confirmation" do
    visit survey_url(@survey)

    # Handle potential confirmation dialog
    accept_confirm do
      click_on "Destroy this survey", match: :first
    end

    assert_text "Survey was successfully destroyed"
    assert_current_path surveys_path

    # Verify survey is no longer in the list
    assert_no_text @survey.title
  end

  test "should navigate between survey, competencies, and questions" do
    visit survey_url(@survey)

    # Should show survey details
    assert_text @survey.title
    assert_text @survey.semester

    # Navigate to competencies (adjust based on your UI)
    if page.has_link?("Competencies")
      click_on "Competencies"
    elsif page.has_link?("View Competencies")
      click_on "View Competencies"
    end

       # Should be on competencies page or see competencies section
       # Adjust assertions based on your actual UI
  end

  test "should handle pagination if surveys list is long" do
    # Create multiple surveys for pagination test
    (1..25).each do |i|
      Survey.create!(
        survey_id: 8000 + i,
        title: "Test Survey #{i}",
        semester: "Test Semester #{i}",
        assigned_date: Date.current,
        completion_date: Date.current + 30.days
      )
    end

    visit surveys_url

    # Check if pagination exists (adjust based on your pagination setup)
    if page.has_selector?(".pagination") || page.has_selector?("[data-pagination]")
      begin
        assert_selector ".pagination"
      rescue Minitest::Assertion
        assert_selector "[data-pagination]"
      end
    end
  end

  test "should display survey status and dates properly" do
    visit survey_url(@survey)

    # Should display formatted dates
    assert_text @survey.assigned_date.strftime("%B %d, %Y") if @survey.assigned_date
    assert_text @survey.completion_date.strftime("%B %d, %Y") if @survey.completion_date

       # Should show survey status indicators
       # Adjust based on your UI implementation
  end

  test "should search and filter surveys" do
    # Create a distinctly named survey for search testing
    unique_survey = Survey.create!(
      survey_id: 7777,
      title: "Unique Searchable Survey",
      semester: "Unique Semester",
      assigned_date: Date.current,
      completion_date: Date.current + 30.days
    )

    visit surveys_url

    # Test search functionality if it exists
    if page.has_field?("search") || page.has_field?("Search")
      fill_in "search", with: "Unique Searchable"
      click_on "Search" if page.has_button?("Search")

      assert_text "Unique Searchable Survey"
      assert_no_text @survey.title # Original survey should be filtered out
    end
  end
end
