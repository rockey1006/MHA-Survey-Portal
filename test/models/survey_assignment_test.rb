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
end
