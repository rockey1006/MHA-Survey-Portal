require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "flash_classes returns expected classes for known keys" do
    assert_includes flash_classes(:notice), "border-blue-500"
    assert_includes flash_classes(:success), "border-emerald-500"
    assert_includes flash_classes(:alert), "border-red-500"
    assert_includes flash_classes(:warning), "border-amber-500"
  end

  test "flash_title returns fallback for unknown keys" do
    assert_equal "Custom Key", flash_title(:custom_key)
  end

  test "tailwind_button_classes returns different variants" do
    primary = tailwind_button_classes(:primary)
    danger = tailwind_button_classes(:danger)
    subtle = tailwind_button_classes(:subtle)

    assert primary.include?("bg-[#500000]")
    assert danger.include?("bg-rose-600")
    assert subtle.include?("bg-slate-100")
  end

  test "humanize_audit_value and list behaviors" do
    assert_equal "none", humanize_audit_value(nil)
    # Empty string should be normalized to "none"
    assert_equal "none", humanize_audit_value("")
    assert_equal "a, b", humanize_audit_list([ "a", "b" ])
    assert_equal "none", humanize_audit_list([])
  end

  test "summarize_survey_audit_metadata builds a short summary" do
    meta = {
      note: "Test note",
      attributes: { title: { before: "Old", after: "New" } },
      associations: { tracks: { before: [ "A" ], after: [ "B" ] } }
    }

    summary = summarize_survey_audit_metadata(meta)
    assert_includes summary, "Test note"
    assert_includes summary, "Title: Old -> New"
    assert_includes summary, "Tracks: A -> B"
  end
end
