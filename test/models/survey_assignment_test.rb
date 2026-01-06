require "test_helper"

class SurveyAssignmentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs

    SurveyAssignment.delete_all
    @survey = surveys(:fall_2025)
    @student = students(:student)
    @advisor = advisors(:advisor)
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "creating an assignment stores student and advisor and enqueues notification" do
    assert_enqueued_jobs 1, only: SurveyNotificationJob do
      assert_difference "SurveyAssignment.count", 1 do
        SurveyAssignment.create!(
          survey: @survey,
          student: @student,
          advisor: @advisor,
          assigned_at: Time.current
        )
      end
    end
  end

  test "mark_completed! persists timestamp" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: Time.current
    )
    refute assignment.completed_at

    assignment.mark_completed!

    assert assignment.completed_at.present?
  end

  test "overdue? and closes_within? evaluate availability windows" do
    now = Time.zone.now
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: now,
      available_until: now + 2.days
    )

    refute assignment.overdue?(now)
    assert assignment.closes_within?(window: 3.days, reference_time: now)
    refute assignment.closes_within?(window: 1.day, reference_time: now)

    assignment.update!(available_until: now - 1.hour)
    assert assignment.overdue?(now)
    refute assignment.closes_within?(window: 3.days, reference_time: now)

    assignment.mark_completed!(now)
    refute assignment.overdue?(now)
    refute assignment.closes_within?(window: 3.days, reference_time: now)
  end

  test "recipient_user and advisor_user resolve backing users" do
    assignment = SurveyAssignment.create!(
      survey: @survey,
      student: @student,
      advisor: @advisor,
      assigned_at: Time.current
    )

    assert_equal @student.user, assignment.recipient_user
    assert_equal @advisor.user, assignment.advisor_user
  end
end
