require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
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

  test "target_path_for returns survey response for completed student assignments" do
    user = users(:student)
    assignment = survey_assignments(:residential_assignment)
    assignment.update!(completed_at: Time.current)
    notification = Notification.create!(user: user, title: "Reminder", message: "Review", notifiable: assignment)

    expected_response = SurveyResponse.build(student: assignment.student, survey: assignment.survey)
    assert_equal survey_response_path(expected_response), notification.target_path_for(user)
  end

  test "target_path_for routes survey notifications by viewer role" do
    survey = surveys(:fall_2025)
    student = users(:student)
    advisor = users(:advisor)
    admin = users(:admin)
    notification = Notification.create!(user: student, title: "Survey Updated", message: "Review changes", notifiable: survey)

    assert_equal survey_path(survey), notification.target_path_for(student)
    assert_equal advisors_survey_path(survey), notification.target_path_for(advisor)
    assert_equal admin_survey_path(survey), notification.target_path_for(admin)
  end
end
