require "test_helper"

class MaintenanceModeTest < ActionDispatch::IntegrationTest
  test "when maintenance enabled, non-admin users are redirected to maintenance page" do
    SiteSetting.set_maintenance_enabled!(true)

    sign_in users(:student)

    get student_dashboard_path
    assert_redirected_to maintenance_path
  ensure
    SiteSetting.set_maintenance_enabled!(false)
  end

  test "when maintenance enabled, admins can still access admin maintenance page" do
    SiteSetting.set_maintenance_enabled!(true)

    sign_in users(:admin)

    get admin_maintenance_path
    assert_response :success
  ensure
    SiteSetting.set_maintenance_enabled!(false)
  end

  test "when maintenance disabled, normal navigation works" do
    SiteSetting.set_maintenance_enabled!(false)

    sign_in users(:student)

    get student_dashboard_path
    assert_response :success
  end
end
