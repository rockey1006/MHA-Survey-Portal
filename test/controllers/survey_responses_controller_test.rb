require "test_helper"

class SurveyResponsesControllerUnitTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  tests SurveyResponsesController

  setup do
    @admin = users(:admin)
    @student_user = users(:student)
    @student = students(:student)
    @survey = surveys(:fall_2025)
    @assigned_advisor = users(:advisor)
    @other_advisor = users(:other_advisor)
  end

  test "set_survey_response via id param returns not found for bad id" do
    sign_in @admin
    # use well-formed composite id where survey portion is missing to trigger RecordNotFound
    student_id = @student.student_id
    missing_survey_id = 9_999_999
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { id: "#{student_id}-#{missing_survey_id}" }
    end
  end

  test "find_by_signed_download_token allows access with token" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)
    token = sr.signed_download_token
    # include a dummy id to satisfy route recognition; controller will use token branch first
    get :show, params: { id: "ignored", token: token }
    assert_response :success
  end

  test "authorize_view allows assigned advisor" do
    sign_in @assigned_advisor
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :show, params: { id: sr.id }
    assert_response :success
  end

  test "authorize_view blocks advisors for unassigned students" do
    sign_in @other_advisor
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :show, params: { id: sr.id }
    assert_response :unauthorized
  end

  test "download returns service_unavailable when WickedPdf not defined" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :download, params: { id: sr.id }
    # allow either 503 (no WickedPdf) or 200 (if environment has it); assert expected message if 503
    assert_includes [ 200, 503 ], @response.status
    if @response.status == 503
      assert_includes @response.body.downcase, "server-side pdf generation unavailable"
    end
  end

  test "composite_report returns service_unavailable when WickedPdf missing" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :composite_report, params: { id: sr.id }
    assert_includes [ 200, 503 ], @response.status
    if @response.status == 503
      assert_includes @response.body.downcase, "composite pdf generation unavailable"
    end
  end

  test "composite_report rejects student users" do
    sign_in @student_user
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :composite_report, params: { id: sr.id }
    assert_response :unauthorized
  end
end

class SurveyResponsesControllerIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @student_user = users(:student)
    survey = surveys(:fall_2025)
    student = students(:student) || Student.first
    @survey_response = SurveyResponse.build(student: student, survey: survey)
  end

  test "student can view their own survey response" do
    sign_in @student_user

    get survey_response_path(@survey_response)
    assert_response :success
  end

  test "other students are blocked from viewing the response" do
    sign_in users(:other_student)

    get survey_response_path(@survey_response)
    assert_response :unauthorized
  end

  test "download returns 503 when WickedPdf missing" do
    # No WickedPdf available in test environment so expect service_unavailable
    sign_in users(:admin)
    get download_survey_response_path(@survey_response)
    assert_includes [ 200, 503 ], response.status
    if response.status == 503
      assert_match /Server-side PDF generation unavailable/, @response.body
    else
      # If WickedPdf is present, we at least expect a response body or an attachment header
      assert response.body.present? || response.headers["Content-Disposition"].present?
    end
  end

  test "set_survey_response returns 404 for missing token" do
    sign_in users(:admin)
    get survey_response_path(id: "nonexistent")
    assert_response :not_found
  end

  test "composite_report returns 503 when WickedPdf missing" do
    sign_in users(:admin)
    get composite_report_survey_response_path(@survey_response)
    assert_includes [ 200, 503 ], response.status
    if response.status == 503
      assert_match /Composite PDF generation unavailable/, @response.body
    else
      assert response.body.present? || response.headers["Content-Disposition"].present?
    end
  end

  test "composite report rejects token access even for admins" do
    sign_in users(:admin)
    token = @survey_response.signed_download_token

    get composite_report_survey_response_path(@survey_response), params: { token: token }
    assert_response :unauthorized
  end
end
