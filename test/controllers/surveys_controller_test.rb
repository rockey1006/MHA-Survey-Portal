require "test_helper"

class SurveysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @survey = surveys(:one)
    @admin = admins(:one)
    @advisor = admins(:two)
  end

  # Tests for admin access
  test "admin should get index" do
    sign_in @admin
    get surveys_url
    assert_response :success
  end

  test "admin should get new" do
    sign_in @admin
    get new_survey_url
    assert_response :success
  end

  test "admin should create survey with valid params" do
    sign_in @admin
    assert_difference("Survey.count") do
      post surveys_url, params: {
        survey: {
          title: "New Test Survey",
          semester: "Fall 2024",
          approval_date: Date.current,
          assigned_date: Date.current + 1.day,
          completion_date: Date.current + 30.days,
          survey_id: 999
        }
      }
    end
    assert_redirected_to survey_url(Survey.last)
  end

  test "admin should not create survey with invalid params" do
    sign_in @admin
    assert_no_difference("Survey.count") do
      post surveys_url, params: {
        survey: {
          title: "",  # Invalid: empty title
          semester: "",
          approval_date: nil,
          assigned_date: nil,
          completion_date: nil,
          survey_id: nil
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "admin should show survey" do
    sign_in @admin
    get survey_url(@survey)
    assert_response :success
  end

  test "admin should get edit" do
    sign_in @admin
    get edit_survey_url(@survey)
    assert_response :success
  end

  test "admin should update survey with valid params" do
    sign_in @admin
    new_title = "Updated Survey Title"
    patch survey_url(@survey), params: {
      survey: {
        title: new_title,
        semester: @survey.semester,
        approval_date: @survey.approval_date,
        assigned_date: @survey.assigned_date,
        completion_date: @survey.completion_date,
        survey_id: @survey.survey_id
      }
    }
    assert_redirected_to survey_url(@survey)
    @survey.reload
    assert_equal new_title, @survey.title
  end

  test "admin should not update survey with invalid params" do
    sign_in @admin
    original_title = @survey.title
    patch survey_url(@survey), params: {
      survey: {
        title: "",  # Invalid: empty title
        semester: @survey.semester
      }
    }
    assert_response :unprocessable_entity
    @survey.reload
    assert_equal original_title, @survey.title
  end

  test "admin should destroy survey" do
    sign_in @admin
    assert_difference("Survey.count", -1) do
      delete survey_url(@survey)
    end
    assert_redirected_to surveys_url
  end

  # Tests for advisor access (if different permissions)
  test "advisor should have limited access" do
    sign_in @advisor
    get surveys_url
    # Adjust based on your authorization logic
    assert_response :success # or :forbidden if advisors can't access
  end

  # Tests for unauthorized access
  test "should redirect to sign in when not authenticated" do
    get surveys_url
    assert_redirected_to new_admin_session_path
  end

  test "should not create survey when not authenticated" do
    assert_no_difference("Survey.count") do
      post surveys_url, params: {
        survey: {
          title: "Test Survey",
          semester: "Fall 2024"
        }
      }
    end
    assert_redirected_to new_admin_session_path
  end

  # Tests for edge cases
  test "should handle non-existent survey gracefully" do
    sign_in @admin
    assert_raises(ActiveRecord::RecordNotFound) do
      get survey_url(99999)
    end
  end

  test "should validate date logic in surveys" do
    sign_in @admin
    # Test that completion date should be after assigned date
    assert_no_difference("Survey.count") do
      post surveys_url, params: {
        survey: {
          title: "Test Survey",
          semester: "Fall 2024",
          assigned_date: Date.current + 30.days,
          completion_date: Date.current,  # Invalid: completion before assignment
          survey_id: 998
        }
      }
    end
       # Adjust assertion based on your actual validation logic
  end
end
