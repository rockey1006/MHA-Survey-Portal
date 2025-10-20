require "test_helper"

class Admin::SurveyChangeLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
  end

  test "index loads recent change logs" do
    get admin_survey_change_logs_path
    assert_response :success
    assert_includes response.body, "Survey Change Log"
    assert_includes response.body, "Initial creation"
  end

  test "index filters by action type" do
    get admin_survey_change_logs_path, params: { action_type: "update" }
    assert_response :success
    assert_includes response.body, "Edited details"
    refute_includes response.body, "Initial creation"
  end
end
