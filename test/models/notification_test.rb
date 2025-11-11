require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "deliver! creates a single notification per user and notifiable" do
    user = users(:student)
    assignment = survey_assignments(:residential_assignment)

    first = Notification.deliver!(
      user: user,
      title: "New Survey Assigned",
      message: "Hello!",
      notifiable: assignment
    )

    second = Notification.deliver!(
      user: user,
      title: "New Survey Assigned",
      message: "Different message",
      notifiable: assignment
    )

    assert_equal first.id, second.id
    assert_equal "Different message", second.reload.message
  end

  test "mark_read! timestamps the record" do
    user = users(:student)
    notification = Notification.create!(
      user: user,
      title: "Reminder",
      message: "Complete your survey"
    )

    notification.mark_read!
    assert_not_nil notification.read_at
  end

  test "deliver! deduplicates by user and title when notifiable is missing" do
    user = users(:student)

    first = Notification.deliver!(user: user, title: "System", message: "Update")
    second = Notification.deliver!(user: user, title: "System", message: "Updated content")

    assert_equal first.id, second.id
    assert_equal "Updated content", user.notifications.find_by(title: "System").message
  end
end
