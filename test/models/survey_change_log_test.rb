require "test_helper"

class SurveyChangeLogTest < ActiveSupport::TestCase
  test "valid with allowed action" do
    log = SurveyChangeLog.new(
      survey: surveys(:fall_2025),
      admin: users(:admin),
      action: "create",
      description: "Created survey"
    )

    assert log.valid?, log.errors.full_messages.to_sentence
  end

  test "invalid with unsupported action" do
    log = SurveyChangeLog.new(
      survey: surveys(:fall_2025),
      admin: users(:admin),
      action: "unexpected"
    )

    refute log.valid?
    assert_includes log.errors[:action], "is not included in the list"
  end

  test "recent scope orders newest first" do
    SurveyChangeLog.delete_all

    older = SurveyChangeLog.create!(
      survey: surveys(:fall_2025),
      admin: users(:admin),
      action: "update",
      created_at: 2.days.ago,
      updated_at: 2.days.ago
    )
    newer = SurveyChangeLog.create!(
      survey: surveys(:fall_2025),
      admin: users(:admin),
      action: "preview",
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )

    assert_equal [ newer, older ], SurveyChangeLog.recent.limit(2).to_a
  end
end
