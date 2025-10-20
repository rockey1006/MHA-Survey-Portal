require "test_helper"

class SurveyChangeLogTest < ActiveSupport::TestCase
  test "change log records action and admin" do
    scl = SurveyChangeLog.new(action: "create", admin: users(:admin), survey: surveys(:fall_2025))
    assert_equal "create", scl.action
    assert_equal users(:admin), scl.admin
  end

  test "to_s (if present) or attributes reflect change" do
    scl = SurveyChangeLog.new(action: "update", admin: users(:admin), survey: surveys(:fall_2025))
    assert_equal "update", scl.action
    assert_equal users(:admin), scl.admin
  end
end
