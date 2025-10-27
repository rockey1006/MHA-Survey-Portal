require "test_helper"

class SurveyNotificationJobTest < ActiveJob::TestCase
  setup do
    @assignment = survey_assignments(:residential_assignment)
  end

  test "assigned event delivers notification to student" do
    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :assigned, survey_assignment_id: @assignment.id)
    end

    notification = Notification.last
    assert_equal @assignment.student.user, notification.user
    assert_equal "New Survey Assigned", notification.title
  end

  test "completed event notifies advisor" do
    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :completed, survey_assignment_id: @assignment.id)
    end

    notification = Notification.last
    assert_equal @assignment.advisor.user, notification.user
    assert_equal "Student Survey Completed", notification.title
  end
end
