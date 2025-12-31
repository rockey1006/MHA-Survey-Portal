require "test_helper"

class ImpersonationReadOnlyTest < ActionDispatch::IntegrationTest
  test "non-GET requests are blocked while impersonating" do
    admin = users(:admin)
    student = users(:student)

    sign_in admin
    post impersonation_path, params: { impersonation: { user_id: student.id.to_s } }
    assert_redirected_to student_dashboard_path

    survey = surveys(:fall_2025)

    post submit_survey_path(survey),
         params: { answers: {} },
         headers: { "HTTP_REFERER" => dashboard_path }

    assert_redirected_to dashboard_path
    assert_match(/read-only while impersonating/i, flash[:alert].to_s)

    delete impersonation_path
    assert_redirected_to admin_dashboard_path
  end
end
