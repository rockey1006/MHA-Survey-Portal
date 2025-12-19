require "test_helper"

class CompositeReportsHelperTest < ActionView::TestCase
  include CompositeReportsHelper

  test "truncate_for_composite_pdf returns unmodified text when within limit" do
    text, truncated = truncate_for_composite_pdf("short", limit: 10)

    assert_equal "short", text
    assert_equal false, truncated
  end

  test "truncate_for_composite_pdf appends suffix when exceeding limit" do
    value = "a" * 10
    text, truncated = truncate_for_composite_pdf(value, limit: 5)

    assert_equal value[0, 5] + CompositeReportsHelper::TRUNCATION_SUFFIX, text
    assert_equal true, truncated
  end

  test "truncate_for_composite_pdf coerces non-string values" do
    text, truncated = truncate_for_composite_pdf(123, limit: 2)

    assert_match(/12.+truncated/i, text)
    assert truncated
  end

  test "composite_answer_parts extracts structured other answers" do
    parts = composite_answer_parts({ "answer" => "Other", "text" => "Custom option" })

    assert_equal "Other", parts[:value]
    assert_equal "Custom option", parts[:text]
  end

  test "composite_answer_parts extracts evidence links" do
    parts = composite_answer_parts({ "link" => "https://example.com", "rating" => 4 })

    assert_equal "https://example.com", parts[:value]
    assert_equal "https://example.com", parts[:link]
    assert_equal 4, parts[:rating]
  end

  test "composite_display_answer prefers structured text" do
    assert_equal "Some details", composite_display_answer({ "answer" => "Other", "text" => "Some details" })
    assert_equal "Yes", composite_display_answer("Yes")
    assert_equal "A, B", composite_display_answer([ "A", "B" ])
  end
end
