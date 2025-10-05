require "test_helper"

class SurveyTest < ActiveSupport::TestCase
  test "valid fixture" do
    assert surveys(:fall_2025).valid?
  end

  test "requires title" do
    survey = Survey.new(semester: "Fall 2025")
    assert_not survey.valid?
    assert_includes survey.errors[:title], "can't be blank"
  end

  test "requires semester" do
    survey = Survey.new(title: "Test Survey")
    assert_not survey.valid?
    assert_includes survey.errors[:semester], "can't be blank"
  end
end
