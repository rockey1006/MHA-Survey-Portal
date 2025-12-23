require "test_helper"

class AdvisorImpersonationTest < ActionDispatch::IntegrationTest
  test "admin can open view-as-advisor page" do
    sign_in users(:admin)

    get new_advisor_impersonation_path
    assert_response :success
    assert_match "View as advisor", response.body
  end

  test "admin can impersonate an advisor and then exit" do
    sign_in users(:admin)

    post advisor_impersonation_path, params: { advisor_impersonation: { user_id: users(:advisor).id } }
    assert_redirected_to advisor_dashboard_path

    follow_redirect!
    assert_response :success
    assert_match "Viewing as", response.body
    assert_match "Exit view", response.body

    delete advisor_impersonation_path
    assert_redirected_to admin_dashboard_path
  end

  test "writes are blocked while impersonating an advisor" do
    sign_in users(:admin)

    post advisor_impersonation_path, params: { advisor_impersonation: { user_id: users(:advisor).id } }
    assert_redirected_to advisor_dashboard_path

    post switch_role_path, params: { role: "student" }

    assert_redirected_to advisor_dashboard_path
    follow_redirect!
    assert_match "Read-only while impersonating", response.body
  end
end
