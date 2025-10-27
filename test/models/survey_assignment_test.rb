require "test_helper"

class SurveyAssignmentTest < ActiveSupport::TestCase
  setup do
    SurveyAssignment.delete_all
    @survey = surveys(:fall_2025)
    @student = students(:student)
    @advisor = advisors(:advisor)
  end

  test "creating an assignment stores student and advisor" do
    assert_difference "SurveyAssignment.count", 1 do
      SurveyAssignment.create!(
        survey: @survey,
        student: @student,
        advisor: @advisor,
        assigned_at: Time.current
      )
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
