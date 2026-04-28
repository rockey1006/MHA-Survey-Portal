require "test_helper"

class StudentCompetencyDashboardTest < ActiveSupport::TestCase
  setup do
    @student = students(:student)
  end

  test "semester options are limited to the student cohort window" do
    ProgramSemester.create!(name: "Fall 2026")
    ProgramSemester.create!(name: "Spring 2027")

    payload = StudentCompetencyDashboard.new(student: @student).call

    assert_equal [ "Fall 2025", "Spring 2026", "Fall 2026", "Spring 2027" ], payload[:semesters]
    assert_equal "Fall 2025", payload[:filters][:semester]
    refute_includes payload[:semesters], "Spring 2025"
  end

  test "semester param outside the cohort window falls back to the allowed default" do
    payload = StudentCompetencyDashboard.new(student: @student, params: { semester: "Spring 2025" }).call

    assert_equal "Fall 2025", payload[:filters][:semester]
  end
end
