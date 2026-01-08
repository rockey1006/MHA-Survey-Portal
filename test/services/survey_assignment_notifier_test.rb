require "test_helper"

class SurveyAssignmentNotifierTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @student = students(:student)
    @advisor = advisors(:advisor)
    @survey = surveys(:fall_2025)
    @reference_time = Time.zone.parse("2025-11-20 12:00:00")

    # Clear existing assignments to ensure clean state
    SurveyAssignment.delete_all
  end

  # === run_due_date_checks! ===

  test "run_due_date_checks! enqueues jobs for assignments due soon" do
    # Create assignment due in 2 days (within 3-day window)
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :due_soon, survey_assignment_id: assignment.id } ]) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! enqueues jobs for assignments due at boundary of window" do
    # Create assignment due in exactly 3 days (at boundary)
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 3.days
    )

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :due_soon, survey_assignment_id: assignment.id } ]) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! does not enqueue for assignments due beyond window" do
    # Create assignment due in 4 days (beyond 3-day window)
    SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 4.days
    )

    assert_no_enqueued_jobs(only: SurveyNotificationJob) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! enqueues jobs for overdue assignments" do
    # Create assignment due yesterday
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 5.days,
      available_until: @reference_time - 1.day
    )

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :past_due, survey_assignment_id: assignment.id } ]) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! enqueues jobs for assignments due right now" do
    # Create assignment due exactly at reference time
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 5.days,
      available_until: @reference_time
    )

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :due_soon, survey_assignment_id: assignment.id } ]) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! does not enqueue for completed assignments" do
    # Create completed assignment that is overdue
    SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 5.days,
      available_until: @reference_time - 1.day,
      completed_at: @reference_time - 2.days
    )

    assert_no_enqueued_jobs(only: SurveyNotificationJob) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! does not enqueue for assignments without due date" do
    # Create assignment with no due date
    SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: nil
    )

    assert_no_enqueued_jobs(only: SurveyNotificationJob) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! enqueues multiple jobs for multiple assignments" do
    # Create multiple due soon assignments
    assignment1 = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 1.day
    )

    other_student = students(:other_student)
    assignment2 = SurveyAssignment.create!(
      survey: @survey,
      student: other_student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    assert_enqueued_jobs(2, only: SurveyNotificationJob) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! enqueues both due_soon and past_due jobs separately" do
    # Create one due soon
    due_soon = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 1.day
    )

    # Create one overdue
    other_student = students(:other_student)
    overdue = SurveyAssignment.create!(
      survey: @survey,
      student: other_student,
      advisor: @advisor,
      assigned_at: @reference_time - 5.days,
      available_until: @reference_time - 1.day
    )

    assert_enqueued_jobs(2, only: SurveyNotificationJob) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! uses Time.current by default" do
    # Create assignment due in 2 days from now
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: Time.current - 1.day,
      available_until: Time.current + 2.days
    )

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :due_soon, survey_assignment_id: assignment.id } ]) do
      SurveyAssignmentNotifier.run_due_date_checks!
    end
  end

  test "run_due_date_checks! with no matching assignments enqueues nothing" do
    # Create assignment well beyond the window
    SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 10.days
    )

    assert_no_enqueued_jobs(only: SurveyNotificationJob) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! handles assignments due just before reference time" do
    # Create assignment due 1 second before reference time (overdue)
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 5.days,
      available_until: @reference_time - 1.second
    )

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :past_due, survey_assignment_id: assignment.id } ]) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! handles assignments due just after window" do
    # Create assignment due just beyond 3-day window
    SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 3.days + 1.second
    )

    assert_no_enqueued_jobs(only: SurveyNotificationJob) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  # === notify_now! ===

  test "notify_now! creates and delivers notification immediately" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    assert_difference "Notification.count", 1 do
      notification = SurveyAssignmentNotifier.notify_now!(
        assignment: assignment,
        title: "Survey Due Soon",
        message: "Please complete your survey by #{assignment.available_until}"
      )

      assert_equal assignment.recipient_user, notification.user
      assert_equal "Survey Due Soon", notification.title
      assert_equal "Please complete your survey by #{assignment.available_until}", notification.message
      assert_equal assignment, notification.notifiable
    end
  end

  test "notify_now! returns the created notification" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    notification = SurveyAssignmentNotifier.notify_now!(
      assignment: assignment,
      title: "Test Notification",
      message: "Test message"
    )

    assert_kind_of Notification, notification
    assert notification.persisted?
  end

  test "notify_now! delivers to correct recipient user" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    notification = SurveyAssignmentNotifier.notify_now!(
      assignment: assignment,
      title: "Assignment Notification",
      message: "Your survey is ready"
    )

    assert_equal @student.user, notification.user
  end

  test "notify_now! sets notifiable to the assignment" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    notification = SurveyAssignmentNotifier.notify_now!(
      assignment: assignment,
      title: "Assignment Notification",
      message: "Your survey is ready"
    )

    assert_equal assignment, notification.notifiable
    assert_equal "SurveyAssignment", notification.notifiable_type
    assert_equal assignment.id, notification.notifiable_id
  end

  test "notify_now! with custom title and message" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    custom_title = "Custom Title #{Time.current}"
    custom_message = "Custom Message #{Time.current}"

    notification = SurveyAssignmentNotifier.notify_now!(
      assignment: assignment,
      title: custom_title,
      message: custom_message
    )

    assert_equal custom_title, notification.title
    assert_equal custom_message, notification.message
  end

  test "notify_now! handles long messages" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    long_message = "A" * 500

    notification = SurveyAssignmentNotifier.notify_now!(
      assignment: assignment,
      title: "Long Message Test",
      message: long_message
    )

    assert_equal long_message, notification.message
  end

  # === DUE_SOON_WINDOW constant ===

  test "DUE_SOON_WINDOW is set to 3 days" do
    assert_equal 3.days, SurveyAssignmentNotifier::DUE_SOON_WINDOW
  end

  # === Edge Cases ===

  test "run_due_date_checks! with different time zones" do
    Time.use_zone("Pacific Time (US & Canada)") do
      pacific_time = Time.zone.parse("2025-11-20 12:00:00")

      assignment = SurveyAssignment.create!(
        survey: @survey,
        student: @student,
        advisor: @advisor,
        assigned_at: pacific_time - 1.day,
        available_until: pacific_time + 2.days
      )

      assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :due_soon, survey_assignment_id: assignment.id } ]) do
        SurveyAssignmentNotifier.run_due_date_checks!(reference_time: pacific_time)
      end
    end
  end

  test "run_due_date_checks! with very old overdue assignments" do
    # Create assignment overdue by 30 days
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 35.days,
      available_until: @reference_time - 30.days
    )

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :past_due, survey_assignment_id: assignment.id } ]) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "run_due_date_checks! processes multiple assignments efficiently" do
    other_student = students(:other_student)
    spring_survey = surveys(:spring_2025)

    # Create multiple assignments due soon using different students and surveys
    assignment1 = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 1.day
    )

    assignment2 = SurveyAssignment.create!(
      survey: spring_survey,
      student: @student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    assignment3 = SurveyAssignment.create!(
      survey: @survey,
      student: other_student,
      advisor: @advisor,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 3.days
    )

    assert_enqueued_jobs(3, only: SurveyNotificationJob) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: @reference_time)
    end
  end

  test "notify_now! with assignment missing advisor" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: nil,
      assigned_at: @reference_time - 1.day,
      available_until: @reference_time + 2.days
    )

    assert_nothing_raised do
      notification = SurveyAssignmentNotifier.notify_now!(
        assignment: assignment,
        title: "No Advisor Test",
        message: "Assignment without advisor"
      )

      assert_equal @student.user, notification.user
    end
  end

  test "run_due_date_checks! with midnight boundary" do
    # Test at exactly midnight
    midnight = Time.zone.parse("2025-11-20 00:00:00")

    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: midnight - 1.day,
      available_until: midnight + 2.days
    )

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :due_soon, survey_assignment_id: assignment.id } ]) do
      SurveyAssignmentNotifier.run_due_date_checks!(reference_time: midnight)
    end
  end
end
