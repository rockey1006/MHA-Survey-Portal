require "test_helper"

class SurveysHelperTest < ActionView::TestCase
  test "competency description returns exact match" do
    desc = competency_description_for("Communication")
    assert_includes desc, "communication"
  end

  test "competency description supports alias lookup" do
    desc = competency_description_for("Legal and ethical considerations")
    assert desc.present?
    assert_includes desc.downcase, "laws"
  end

  test "competency description returns nil for unrelated prompts" do
    assert_nil competency_description_for("Random reflection question")
  end
end
