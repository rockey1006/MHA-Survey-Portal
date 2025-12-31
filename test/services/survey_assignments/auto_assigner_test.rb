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

    test "skips assignment when program year is blank" do
      @student.update_columns(track: "Residential", program_year: nil)

      assert_no_difference -> { SurveyAssignment.count } do
        AutoAssigner.call(student: @student)
      end
    end

    test "assigns surveys matching the student's track" do
      @student.update_columns(track: "Residential", program_year: 1)

      assert_difference -> { @student.survey_assignments.count }, 1 do
        AutoAssigner.call(student: @student)
      end

      assignment = @student.survey_assignments.find_by(survey: surveys(:fall_2025))
      assert_not_nil assignment
      assert_equal @student.advisor_id, assignment.advisor_id
      assert_not_nil assignment.assigned_at
      assert_equal surveys(:fall_2025).due_date.to_date, assignment.due_date.to_date
      refute_includes @student.survey_assignments.pluck(:survey_id), surveys(:spring_2025).id
    end

    test "does not auto-assign surveys without due dates" do
      ProgramSemester.find_or_create_by!(name: "Spring 2026").update!(current: true)
      ProgramSemester.where.not(name: "Spring 2026").update_all(current: false)

      @student.update_columns(track: "Residential", program_year: 1)

      assert_no_difference -> { @student.survey_assignments.count } do
        AutoAssigner.call(student: @student)
      end
    ensure
      ProgramSemester.find_or_create_by!(name: "Fall 2025").update!(current: true)
      ProgramSemester.where.not(name: "Fall 2025").update_all(current: false)
    end

    test "does not auto-assign surveys that are overdue" do
      survey = surveys(:fall_2025)
      original_due_date = survey.due_date
      survey.update!(due_date: 1.day.ago.change(hour: 23, min: 59, sec: 0))

      @student.update_columns(track: "Residential", program_year: 1)

      assert_no_difference -> { @student.survey_assignments.count } do
        AutoAssigner.call(student: @student)
      end
    ensure
      survey.update!(due_date: original_due_date)
      ProgramSemester.find_or_create_by!(name: "Fall 2025").update!(current: true)
      ProgramSemester.where.not(name: "Fall 2025").update_all(current: false)
    end

    test "replaces assignments when the track changes" do
      @student.update_columns(track: "Residential", program_year: 1)
      AutoAssigner.call(student: @student)

      @student.update_columns(track: "Executive")
      AutoAssigner.call(student: @student)

      assert_equal [ surveys(:fall_2025_executive).id ], @student.survey_assignments.pluck(:survey_id)
    end

    test "keeps completed assignments when the track changes" do
      @student.update_columns(track: "Residential", program_year: 1)
      AutoAssigner.call(student: @student)

      assignment = @student.survey_assignments.find_by!(survey: surveys(:fall_2025))
      completion_time = 2.days.ago.change(usec: 0)
      assignment.update!(completed_at: completion_time)

      @student.update_columns(track: "Executive")
      AutoAssigner.call(student: @student)

      assignment.reload
      assert_equal completion_time, assignment.completed_at

      survey_ids = @student.survey_assignments.pluck(:survey_id)
      assert_includes survey_ids, surveys(:fall_2025).id
      assert_includes survey_ids, surveys(:fall_2025_executive).id
      refute_includes survey_ids, surveys(:spring_2025).id
    end

    test "uses the semester marked current when selecting surveys" do
      ProgramSemester.find_or_create_by!(name: "Spring 2025").update!(current: true)
      ProgramSemester.where.not(name: "Spring 2025").update_all(current: false)

      @student.update_columns(track: "Executive", program_year: 1)
      AutoAssigner.call(student: @student)

      assert_equal [ surveys(:spring_2025).id ], @student.survey_assignments.pluck(:survey_id)
    ensure
      ProgramSemester.find_or_create_by!(name: "Fall 2025").update!(current: true)
      ProgramSemester.where.not(name: "Fall 2025").update_all(current: false)
    end
  end
end
