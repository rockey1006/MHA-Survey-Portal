# frozen_string_literal: true

require "caxlsx"

module Reports
  # Builds an Excel workbook summarizing the analytics dataset for offline review.
  class ExcelExporter
    SECTION_SHEETS = {
      "benchmark" => %i[add_summary_sheet],
      "competency" => %i[add_competency_sheet],
      "course" => %i[add_course_sheet],
      "alignment" => %i[add_alignment_sheet]
    }.freeze
    DEFAULT_SHEETS = SECTION_SHEETS.values.flatten.uniq.freeze

    def initialize(payload, section: nil)
      @payload = payload.deep_symbolize_keys
      @section = section.to_s.presence
    end

    def generate
      package = Axlsx::Package.new
      workbook = package.workbook

      sheet_methods_for_export.each do |method_name|
        send(method_name, workbook)
      end

      package
    end

    private

    attr_reader :payload, :section

    def sheet_methods_for_export
      SECTION_SHEETS.fetch(section, DEFAULT_SHEETS)
    end

    def add_summary_sheet(workbook)
      benchmark = payload[:benchmark] || {}
      cards = Array(benchmark[:cards])
      filters = payload[:filters] || {}
      timeline = Array(benchmark[:timeline])

      workbook.add_worksheet(name: "Summary") do |sheet|
        sheet.add_row [ "Generated At", format_timestamp(payload[:generated_at]) ]
        sheet.add_row []
        sheet.add_row [ "Active Filters" ]
        filters.each do |label, value|
          sheet.add_row [ label.to_s.titleize, value ]
        end

        sheet.add_row []
        sheet.add_row [ "Metric", "Value", "Change", "Description", "Sample Size" ]
        cards.each do |card|
          sheet.add_row [
            card[:title],
            formatted_value(card[:value], card[:unit], card[:precision]),
            formatted_change(card[:change], card[:unit]),
            card[:description],
            card[:sample_size]
          ]
        end

        next if timeline.blank?

        sheet.add_row []
        sheet.add_row [ "Timeline" ]
        sheet.add_row [ "Month", "Student Average", "Advisor Average", "Alignment %" ]
        timeline.each do |point|
          sheet.add_row [
            point[:label],
            format_number(point[:student], 2),
            format_number(point[:advisor], 2),
            format_number(point[:alignment], 1)
          ]
        end
      end
    end

    def add_competency_sheet(workbook)
      summary = Array(payload[:competency_summary])
      return if summary.blank?

      workbook.add_worksheet(name: "Competencies") do |sheet|
        sheet.add_row [
          "Competency",
          "Student Avg",
          "Advisor Avg",
          "Gap",
          "Trend %",
          "Status",
          "Student Sample",
          "Advisor Sample",
          "Achieved",
          "Not Met",
          "Not Assessed",
          "Achieved %",
          "Not Met %",
          "Not Assessed %"
        ]

        summary.each do |entry|
          sheet.add_row [
            entry[:name],
            format_number(entry[:student_average], 2),
            format_number(entry[:advisor_average], 2),
            format_number(entry[:gap], 2),
            formatted_change(entry[:change], "percent"),
            entry[:status].to_s.titleize,
            entry[:student_sample],
            entry[:advisor_sample],
            entry[:achieved_count],
            entry[:not_met_count],
            entry[:not_assessed_count],
            format_number(entry[:achieved_percent], 1, suffix: "%"),
            format_number(entry[:not_met_percent], 1, suffix: "%"),
            format_number(entry[:not_assessed_percent], 1, suffix: "%")
          ]
        end
      end
    end

    def add_course_sheet(workbook)
      courses = Array(payload[:course_summary])
      return if courses.blank?

      workbook.add_worksheet(name: "Courses") do |sheet|
        sheet.add_row [
          "Survey",
          "Semester",
          "Track",
          "Student Avg",
          "Advisor Avg",
          "Gap",
          "On Track %",
          "Submissions",
          "Achieved",
          "Not Met",
          "Not Assessed",
          "Achieved %",
          "Not Met %",
          "Not Assessed %"
        ]

        courses.each do |entry|
          sheet.add_row [
            entry[:title],
            entry[:semester],
            entry[:track],
            format_number(entry[:student_average], 2),
            format_number(entry[:advisor_average], 2),
            format_number(entry[:gap], 2),
            format_number(entry[:on_track_percent], 1, suffix: "%"),
            entry[:submissions],
            entry[:achieved_count],
            entry[:not_met_count],
            entry[:not_assessed_count],
            format_number(entry[:achieved_percent], 1, suffix: "%"),
            format_number(entry[:not_met_percent], 1, suffix: "%"),
            format_number(entry[:not_assessed_percent], 1, suffix: "%")
          ]
        end
      end
    end

    def add_alignment_sheet(workbook)
      data = payload[:alignment] || {}
      labels = Array(data[:labels])
      return if labels.blank?

      workbook.add_worksheet(name: "Alignment") do |sheet|
        sheet.add_row [ "Competency", "Student Avg", "Advisor Avg", "Gap" ]

        labels.each_with_index do |label, index|
          sheet.add_row [
            label,
            format_number(Array(data[:student])[index], 2),
            format_number(Array(data[:advisor])[index], 2),
            format_number(Array(data[:gap])[index], 2)
          ]
        end
      end
    end

    def formatted_value(value, unit, precision)
      return nil if value.nil?

      case unit
      when "percent"
        format_number(value, precision || 0, suffix: "%")
      else
        format_number(value, precision || 1)
      end
    end

    def formatted_change(change, unit)
      return nil if change.nil?

      prefix = change.positive? ? "+" : ""
      case unit
      when "percent"
        "#{prefix}#{format_number(change, 1)}%"
      else
        "#{prefix}#{format_number(change, 1)}"
      end
    end

    def format_number(value, precision = 2, suffix: nil)
      return nil if value.nil?

      formatted = format("%0.#{precision}f", value)
      suffix ? "#{formatted}#{suffix}" : formatted
    end

    def format_timestamp(value)
      return nil unless value

      value.in_time_zone.strftime("%Y-%m-%d %H:%M %Z")
    end
  end
end
