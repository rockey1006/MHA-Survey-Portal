require "test_helper"

class SurveyTest < ActiveSupport::TestCase
  test "active scope returns active surveys" do
    active = Survey.where(is_active: true).to_a
    assert active.present?
    assert_equal active.sort_by(&:id), Survey.active.order(:id).to_a
  end

  test "survey has questions association and questions can be ordered" do
    survey = surveys(:fall_2025)
    assert_respond_to survey, :questions
    ordered = survey.questions.ordered.to_a
    assert_kind_of Array, ordered
  end
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
