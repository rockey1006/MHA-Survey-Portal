# frozen_string_literal: true

require "test_helper"

module Reports
  class DataAggregatorTrackSummaryTest < ActiveSupport::TestCase
    include Devise::Test::IntegrationHelpers

    setup do
      @admin = users(:admin)
    end

    test "track_summary aggregates into program track rows" do
      aggregator = Reports::DataAggregator.new(user: @admin, params: {})

      # Force deterministic track list so the summary always returns exactly these rows
      aggregator.stub(:program_track_names, [ "Executive", "Residential" ]) do
        # Avoid DB dependence in this unit-style test; we stub assignment counts.
        aggregator.stub(:assigned_student_count_for_track, 5) do
          rows = [
            # Executive: student 1 achieved (avg 4.0 >= target 4.0)
            {
              score: 4.0,
              advisor_entry: false,
              track: "Executive",
              student_id: 1,
              program_target_level: 4.0,
              question_text: "Communication",
              survey_id: 1
            },
            # Executive: student 2 not met (avg 3.0 < target 4.0)
            {
              score: 3.0,
              advisor_entry: false,
              track: "Executive",
              student_id: 2,
              program_target_level: 4.0,
              question_text: "Communication",
              survey_id: 1
            },
            # Residential: student 3 achieved (avg 5.0 >= target 4.0)
            {
              score: 5.0,
              advisor_entry: false,
              track: "Residential",
              student_id: 3,
              program_target_level: 4.0,
              question_text: "Communication",
              survey_id: 2
            },
            # Advisor rows should not affect achieved/not_met counts (they are excluded)
            {
              score: 4.5,
              advisor_entry: true,
              track: "Residential",
              student_id: 3,
              program_target_level: 4.0,
              question_text: "Communication",
              survey_id: 2
            }
          ]

          aggregator.stub(:dataset_rows, rows) do
            track_summary = aggregator.track_summary

            assert_equal 2, track_summary.size
            assert_equal [ "Executive", "Residential" ], track_summary.map { |entry| entry[:track] }

            executive = track_summary.find { |entry| entry[:track] == "Executive" }
            residential = track_summary.find { |entry| entry[:track] == "Residential" }

            assert_equal 1, executive[:achieved_count]
            assert_equal 1, executive[:not_met_count]
            assert_equal 3, executive[:not_assessed_count]

            assert_equal 1, residential[:achieved_count]
            assert_equal 0, residential[:not_met_count]
            assert_equal 4, residential[:not_assessed_count]

            assert_in_delta 20.0, executive[:achieved_percent], 0.001
            assert_in_delta 20.0, executive[:not_met_percent], 0.001
            assert_in_delta 60.0, executive[:not_assessed_percent], 0.001

            assert_in_delta 20.0, residential[:achieved_percent], 0.001
            assert_in_delta 0.0, residential[:not_met_percent], 0.001
            assert_in_delta 80.0, residential[:not_assessed_percent], 0.001
          end
        end
      end
    end

    test "track_summary includes a row for each program track even without data" do
      aggregator = Reports::DataAggregator.new(user: @admin, params: {})

      aggregator.stub(:program_track_names, [ "Executive", "Residential" ]) do
        aggregator.stub(:assigned_student_count_for_track, 0) do
          aggregator.stub(:dataset_rows, []) do
            summary = aggregator.track_summary

            assert_equal 2, summary.size
            assert_equal [ "Executive", "Residential" ], summary.map { |entry| entry[:track] }

            summary.each do |entry|
              assert_nil entry[:achieved_percent]
              assert_nil entry[:not_met_percent]
              assert_nil entry[:not_assessed_percent]
              assert_equal 0, entry[:achieved_count]
              assert_equal 0, entry[:not_met_count]
              assert_equal 0, entry[:not_assessed_count]
            end
          end
        end
      end
    end
  end
end
