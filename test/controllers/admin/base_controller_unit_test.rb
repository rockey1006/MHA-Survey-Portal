require "test_helper"

class AdminBaseControllerUnitTest < ActiveSupport::TestCase
  test "current_admin_profile returns the admin profile" do
    controller = Admin::QuestionsController.new
    admin_user = users(:admin)

    controller.stub(:current_user, admin_user) do
      assert_instance_of Admin, controller.send(:current_admin_profile)
    end
  end
end
