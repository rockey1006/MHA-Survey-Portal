require "test_helper"

class SurveySectionTest < ActiveSupport::TestCase
  setup do
    @survey = surveys(:fall_2025)
  end

  test "normalizes blank title to a default" do
    section = SurveySection.new(survey: @survey, title: "")

    assert section.valid?
    assert_equal "Untitled section", section.title
  end

  test "auto assigns a position when omitted" do
    first = SurveySection.create!(survey: @survey, title: "First Section", description: "Intro")
    second = SurveySection.create!(survey: @survey, title: "Second Section")

    assert first.position >= 0
    assert_equal first.position + 1, second.position
  end

  test "identifies mha competency section" do
    section = SurveySection.new(survey: @survey, title: "  MHA Competency Self-Assessment  ")

    assert section.mha_competency?

    section.title = "Professional Snapshot"

    refute section.mha_competency?
  end
end
