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

  test "response submitted event thanks student" do
    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :response_submitted, survey_assignment_id: @assignment.id)
    end

    notification = Notification.last
    assert_equal @assignment.student.user, notification.user
    assert_equal "Survey Submitted", notification.title
  end

  test "question updated event notifies survey participants" do
    question = questions(:fall_q1)

    assert_difference -> { Notification.count }, 2 do
      SurveyNotificationJob.perform_now(event: :question_updated, question_id: question.id, metadata: { editor_name: "Admin" })
    end

    recipients = Notification.last(2).map(&:user)
    assert_includes recipients, users(:student)
    assert_includes recipients, users(:advisor)
    assert_equal "Question Updated", Notification.last.title
  end
end
