require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:student)
    sign_in @user
  end

  test "index renders successfully" do
    get notifications_path
    assert_response :success
  end

  test "show marks the notification as read" do
    notification = Notification.create!(user: @user, title: "Reminder", message: "Check your survey")
    assert_nil notification.read_at

    get notification_path(notification)
    assert_response :success
    assert_not_nil notification.reload.read_at
  end

  test "mark all read clears unread count" do
    Notification.create!(user: @user, title: "Reminder", message: "Check your survey")

    patch mark_all_read_notifications_path

    assert_redirected_to notifications_path
    assert_equal 0, @user.notifications.unread.count
  end
end
