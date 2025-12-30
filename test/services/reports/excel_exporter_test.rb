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
              alignment: 90.0,
              student_target_percent: 55.0,
              advisor_target_percent: 60.0
            }
          ]
        },
        competency_summary: [
          {
            name: "Health Care Environment and Community",
            student_average: 3.0,
            advisor_average: 3.2,
            program_target_level: 4.0,
            student_target_percent: 50.0,
            advisor_target_percent: 40.0,
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
              program_target_level: 4.0,
              student_target_percent: 50.0,
              advisor_target_percent: 40.0,
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
      assert_includes sheet_names, "Summary"
      assert_includes sheet_names, "Competencies"
      assert_includes sheet_names, "Competency Detail"

      summary_sheet = package.workbook.worksheets.find { |ws| ws.name == "Summary" }
      competency_sheet = package.workbook.worksheets.find { |ws| ws.name == "Competencies" }
      detail_sheet = package.workbook.worksheets.find { |ws| ws.name == "Competency Detail" }

      summary_header = summary_sheet.rows.find { |row| row.cells.any? { |c| c.value == "Month" } }
      assert summary_header
      summary_header_values = summary_header.cells.map(&:value)
      assert_includes summary_header_values, "Student % Meeting Target"
      assert_includes summary_header_values, "Advisor % Meeting Target"

      competency_header = competency_sheet.rows.first
      competency_header_values = competency_header.cells.map(&:value)
      assert_includes competency_header_values, "Program Target Level"
      assert_includes competency_header_values, "Student % Meeting Target"
      assert_includes competency_header_values, "Advisor % Meeting Target"

      detail_header = detail_sheet.rows.first
      detail_header_values = detail_header.cells.map(&:value)
      assert_includes detail_header_values, "Program Target Level"
      assert_includes detail_header_values, "Student % Meeting Target"
      assert_includes detail_header_values, "Advisor % Meeting Target"
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

      package = Reports::ExcelExporter.new(payload, section: "track").generate
      sheet_names = package.workbook.worksheets.map(&:name)
      assert_includes sheet_names, "Tracks"
      assert_equal false, sheet_names.include?("Courses")

      tracks_sheet = package.workbook.worksheets.find { |ws| ws.name == "Tracks" }
      assert tracks_sheet
      header_values = tracks_sheet.rows.first.cells.map(&:value)
      assert_equal "Track", header_values.first
      assert_includes header_values, "Achieved %"
      assert_includes header_values, "Not Met %"
      assert_includes header_values, "Not Assessed %"
    end
  end
end
