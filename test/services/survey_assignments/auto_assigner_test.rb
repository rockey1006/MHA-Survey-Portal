# frozen_string_literal: true

require "test_helper"

module SurveyAssignments
  class AutoAssignerTest < ActiveSupport::TestCase
    setup do
      @student = students(:student)
      @student.survey_assignments.destroy_all
    end

    test "skips assignment when track is blank" do
      @student.update_columns(track: nil)

      assert_no_difference -> { SurveyAssignment.count } do
        AutoAssigner.call(student: @student)
      end
    end

    test "assigns surveys matching the student's track" do
      @student.update_columns(track: "Residential")

      assert_difference -> { @student.survey_assignments.count }, 1 do
        AutoAssigner.call(student: @student)
      end

      assignment = @student.survey_assignments.find_by(survey: surveys(:fall_2025))
      assert_not_nil assignment
      assert_equal @student.advisor_id, assignment.advisor_id
      assert_not_nil assignment.assigned_at
    end

    test "replaces assignments when the track changes" do
      @student.update_columns(track: "Residential")
      AutoAssigner.call(student: @student)

      @student.update_columns(track: "Executive")
      AutoAssigner.call(student: @student)

      assert_equal [ surveys(:spring_2025).id ], @student.survey_assignments.pluck(:survey_id)
    end
  end
end
