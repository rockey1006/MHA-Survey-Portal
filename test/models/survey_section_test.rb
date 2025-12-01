require "test_helper"

class SurveySectionTest < ActiveSupport::TestCase
  setup do
    @survey = surveys(:fall_2025)
  end

  test "requires a title" do
    section = SurveySection.new(survey: @survey)

    assert_not section.valid?
    assert_includes section.errors[:title], "can't be blank"
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
