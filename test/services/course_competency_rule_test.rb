require "test_helper"

class CourseCompetencyRuleTest < ActiveSupport::TestCase
  test "normalize falls back to default for invalid values" do
    assert_equal "max", CourseCompetencyRule.normalize(nil)
    assert_equal "max", CourseCompetencyRule.normalize("unknown")
  end

  test "aggregate supports max min avg ceil_avg and floor_avg" do
    values = [ 2.0, 4.0, 5.0 ]

    assert_equal 5.0, CourseCompetencyRule.aggregate(values, rule_key: "max")
    assert_equal 2.0, CourseCompetencyRule.aggregate(values, rule_key: "min")
    assert_in_delta 11.0 / 3.0, CourseCompetencyRule.aggregate(values, rule_key: "avg"), 0.001
    assert_equal 4, CourseCompetencyRule.aggregate(values, rule_key: "ceil_avg")
    assert_equal 3, CourseCompetencyRule.aggregate(values, rule_key: "floor_avg")
  end
end
