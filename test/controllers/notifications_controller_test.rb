require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @student = users(:student)
    @advisor = users(:advisor)
    @student_notification = notifications(:student_unread)
    @advisor_notification = notifications(:advisor_notice)
  end

  test "index lists only current user's notifications" do
    sign_in @student

    get notifications_path
    assert_response :success
    assert_includes response.body, @student_notification.title
    refute_includes response.body, @advisor_notification.title
  end

  test "show marks the owner's notification as read" do
    sign_in @student
    assert_nil @student_notification.read_at

    get notification_path(@student_notification)
    assert_response :success
    assert_not_nil @student_notification.reload.read_at
  end

  test "show responds 404 when accessing another user's notification" do
    sign_in @student

    get notification_path(@advisor_notification)
    assert_response :not_found
  end

  test "update marks notification as read and redirects back" do
    sign_in @student

    patch notification_path(@student_notification), headers: { "HTTP_REFERER" => notifications_url }
    assert_redirected_to notifications_path
    assert @student_notification.reload.read_at.present?, "expected notification to be marked read"
  end

  test "mark all read clears unread count" do
    sign_in @student

    patch mark_all_read_notifications_path, headers: { "HTTP_REFERER" => notifications_url }

    assert_redirected_to notifications_path
    assert_equal 0, @student.notifications.unread.count
  end
end
