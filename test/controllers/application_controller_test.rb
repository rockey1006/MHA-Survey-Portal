require "test_helper"

class ApplicationControllerTest < ActiveSupport::TestCase
  test "current_student memoizes the student's profile" do
    controller = ApplicationController.new
    user = users(:student)

    controller.singleton_class.define_method(:current_user) { user }
    first = controller.send(:current_student)
    second = controller.send(:current_student)

    assert_same first, second
    assert_equal students(:student), first
  ensure
    controller.singleton_class.send(:remove_method, :current_user)
  end

  test "current_advisor_profile memoizes advisor profile" do
    controller = ApplicationController.new
    user = users(:advisor)

    controller.singleton_class.define_method(:current_user) { user }
    first = controller.send(:current_advisor_profile)
    second = controller.send(:current_advisor_profile)

    assert_same first, second
    assert_equal advisors(:advisor), first
  ensure
    controller.singleton_class.send(:remove_method, :current_user)
  end

  test "load_notification_state sets unread counts and recent notifications" do
    controller = ApplicationController.new
    user = users(:student)

    controller.singleton_class.define_method(:current_user) { user }
    controller.send(:load_notification_state)

    assert_equal user.notifications.unread.count, controller.instance_variable_get(:@unread_notification_count)
    assert_equal 10, controller.instance_variable_get(:@recent_notifications).limit_value
  ensure
    controller.singleton_class.send(:remove_method, :current_user)
  end

  test "fallback semester label returns formatted timestamp" do
    controller = ApplicationController.new
    label = controller.send(:fallback_semester_label)

    assert_match(/\A[A-Z][a-z]+ \d{4}\z/, label)
  end
end
