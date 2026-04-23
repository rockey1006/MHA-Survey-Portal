# frozen_string_literal: true

require "test_helper"

module Reports
  class ExcelExporterTest < ActiveSupport::TestCase
    test "exports include target percent and target level columns" do
      payload = {
        generated_at: Time.zone.parse("2025-12-01 10:00"),
        filters: { track: "All tracks" },
        benchmark: {
          cards: [],
          timeline: [
            {
              label: "Dec 2025",
              student: 3.5,
              advisor: 4.0,
              course: 4.1,
              alignment: 90.0,
              student_target_percent: 55.0,
              advisor_target_percent: 60.0,
              course_target_percent: 65.0
            }
          ]
        },
        competency_summary: [
          {
            name: "Health Care Environment and Community",
            student_average: 3.0,
            advisor_average: 3.2,
            course_average: 4.1,
            program_target_level: 4.0,
            student_target_percent: 50.0,
            advisor_target_percent: 40.0,
            course_target_percent: 65.0,
            gap: 0.2,
            change: 1.0,
            status: "watch",
            student_sample: 1,
            advisor_sample: 1,
            achieved_count: 0,
            not_met_count: 1,
            not_assessed_count: 0,
            achieved_percent: 0.0,
            not_met_percent: 100.0,
            not_assessed_percent: 0.0
          }
        ],
        competency_detail: {
          items: [
            {
              name: "Public and Population Health Assessment",
              domain_name: "Health Care Environment and Community",
              student_average: 3.0,
              advisor_average: 3.2,
              course_average: 4.1,
              program_target_level: 4.0,
              student_target_percent: 50.0,
              advisor_target_percent: 40.0,
              course_target_percent: 65.0,
              gap: 0.2,
              achieved_count: 0,
              not_met_count: 1,
              not_assessed_count: 0,
              achieved_percent: 0.0,
              not_met_percent: 100.0,
              not_assessed_percent: 0.0
            }
          ]
        },
        track_summary: []
      }

      package = Reports::ExcelExporter.new(payload).generate
      sheet_names = package.workbook.worksheets.map(&:name)
      assert_equal [ "Trend", "Domain", "Competency", "Track", "Employment" ], sheet_names

      summary_sheet = package.workbook.worksheets.find { |ws| ws.name == "Trend" }
      competency_sheet = package.workbook.worksheets.find { |ws| ws.name == "Domain" }
      detail_sheet = package.workbook.worksheets.find { |ws| ws.name == "Competency" }

      summary_header = summary_sheet.rows.find { |row| row.cells.any? { |c| c.value == "Month" } }
      assert summary_header
      summary_header_values = summary_header.cells.map(&:value)
      assert_includes summary_header_values, "Student % Meeting Target"
      assert_includes summary_header_values, "Advisor % Meeting Target"
      assert_includes summary_header_values, "Course % Meeting Target"

      competency_header = competency_sheet.rows.first
      competency_header_values = competency_header.cells.map(&:value)
      assert_includes competency_header_values, "Program Target Level"
      assert_includes competency_header_values, "Course Avg"
      assert_includes competency_header_values, "Student % Meeting Target"
      assert_includes competency_header_values, "Advisor % Meeting Target"
      assert_includes competency_header_values, "Course % Meeting Target"

      detail_header = detail_sheet.rows.first
      detail_header_values = detail_header.cells.map(&:value)
      assert_includes detail_header_values, "Program Target Level"
      assert_includes detail_header_values, "Course Avg"
      assert_includes detail_header_values, "Student % Meeting Target"
      assert_includes detail_header_values, "Advisor % Meeting Target"
      assert_includes detail_header_values, "Course % Meeting Target"
    end

    test "track section export includes Tracks sheet and excludes Courses sheet" do
      payload = {
        generated_at: Time.zone.parse("2025-12-01 10:00"),
        filters: { track: "All tracks" },
        benchmark: { cards: [], timeline: [] },
        competency_summary: [],
        competency_detail: { items: [] },
        track_summary: [
          {
            track: "Executive",
            student_average: 4.0,
            advisor_average: 4.2,
            gap: 0.2,
            submissions: 2,
            achieved_count: 2,
            not_met_count: 0,
            not_assessed_count: 0,
            achieved_percent: 100.0,
            not_met_percent: 0.0,
            not_assessed_percent: 0.0
          }
        ]
      }

      package = Reports::ExcelExporter.new(payload).generate
      sheet_names = package.workbook.worksheets.map(&:name)
      assert_equal [ "Trend", "Domain", "Competency", "Track", "Employment" ], sheet_names

      tracks_sheet = package.workbook.worksheets.find { |ws| ws.name == "Track" }
      assert tracks_sheet
      header_values = tracks_sheet.rows.first.cells.map(&:value)
      assert_equal "Track", header_values.first
      assert_includes header_values, "Achieved %"
      assert_includes header_values, "Not Met %"
      assert_includes header_values, "Not Assessed %"
    end
  end
end
