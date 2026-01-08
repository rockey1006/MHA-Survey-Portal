# frozen_string_literal: true

require "test_helper"

class SurveyOfferingAssignmentGroupTest < ActiveSupport::TestCase
  test "for_student prefers grouped offerings when assignment_group has matches" do
    ProgramTrack.seed_defaults!

    default_survey = surveys(:fall_2025)
    grouped_survey = surveys(:fall_2025_executive)

    SurveyOffering.create!(
      survey: default_survey,
      track: "Residential",
      class_of: 2026,
      stage: "midpoint",
      active: true,
      assignment_group: nil
    )

    SurveyOffering.create!(
      survey: grouped_survey,
      track: "Residential",
      class_of: 2026,
      stage: "midpoint",
      active: true,
      assignment_group: "A"
    )

    offerings = SurveyOffering.for_student(track_key: "residential", class_of: 2026, assignment_group: "A")

    assert_equal [ grouped_survey.id ], offerings.pluck(:survey_id).uniq.sort
  end

  test "for_student falls back to ungrouped offerings when group has no matches" do
    ProgramTrack.seed_defaults!

    default_survey = surveys(:fall_2025)

    SurveyOffering.create!(
      survey: default_survey,
      track: "Residential",
      class_of: 2026,
      stage: "midpoint",
      active: true,
      assignment_group: nil
    )

    offerings = SurveyOffering.for_student(track_key: "residential", class_of: 2026, assignment_group: "NON_EXISTENT")

    assert_equal [ default_survey.id ], offerings.pluck(:survey_id).uniq.sort
  end

  test "for_student uses ungrouped offerings when assignment_group is blank" do
    ProgramTrack.seed_defaults!

    default_survey = surveys(:fall_2025)

    SurveyOffering.create!(
      survey: default_survey,
      track: "Residential",
      class_of: 2026,
      stage: "midpoint",
      active: true,
      assignment_group: nil
    )

    offerings = SurveyOffering.for_student(track_key: "residential", class_of: 2026, assignment_group: "")

    assert_equal [ default_survey.id ], offerings.pluck(:survey_id).uniq.sort
  end
end
