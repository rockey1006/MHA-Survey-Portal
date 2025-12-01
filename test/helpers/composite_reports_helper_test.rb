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
end
