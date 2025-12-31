require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "flash_classes returns expected classes for known keys" do
    assert_includes flash_classes(:notice), "flash__notice"
    assert_includes flash_classes(:success), "flash__success"
    assert_includes flash_classes(:alert), "flash__alert"
    assert_includes flash_classes(:warning), "flash__warning"
  end

  test "flash_title returns fallback for unknown keys" do
    assert_equal "Custom Key", flash_title(:custom_key)
  end

  test "tailwind_button_classes returns different variants" do
    primary = tailwind_button_classes(:primary)
    danger = tailwind_button_classes(:danger)
    subtle = tailwind_button_classes(:subtle)

    assert_includes primary, "btn-primary"
    assert_includes danger, "btn-danger"
    assert_includes subtle, "btn-subtle"

    refute_equal primary, danger
    refute_equal primary, subtle
  end

  test "tailwind_button_classes falls back for unknown variant and appends extra classes" do
    classes = tailwind_button_classes(:unknown_variant, extra_classes: "mt-2")
    assert_includes classes, "btn"
    assert_includes classes, "btn-secondary"
    assert_includes classes, "mt-2"
  end

  test "survey_due_note handles blank, overdue, today, and future" do
    assert_equal "No due date", survey_due_note(nil)

    today = Time.zone.today
    assert_equal "Due today", survey_due_note(today)

    overdue = today - 1
    assert_includes survey_due_note(overdue), "Overdue"

    future = today + 5
    assert_includes survey_due_note(future), "Due"
  end

  test "survey_status_badge_classes maps status variants" do
    assert_includes survey_status_badge_classes("completed"), "emerald"
    assert_includes survey_status_badge_classes("assigned"), "amber"
    assert_includes survey_status_badge_classes("unassigned"), "slate"
    assert_includes survey_status_badge_classes("unknown"), "slate"
  end

  test "avatar_aria_label falls back when user missing or name blank" do
    assert_equal "User avatar", avatar_aria_label(nil)

    user = Struct.new(:full_name).new(" ")
    assert_equal "User avatar", avatar_aria_label(user)

    user = Struct.new(:full_name).new("Ada Lovelace")
    assert_equal "Profile picture for Ada Lovelace", avatar_aria_label(user)
  end

  test "scale_labels_for uses question labels when present" do
    question = Struct.new(:answer_options_list).new([ "A", "B" ])
    assert_equal [ "A", "B" ], scale_labels_for(question)

    question = Struct.new(:answer_options_list).new([])
    assert_equal DEFAULT_SCALE_LABELS, scale_labels_for(question)
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

  test "scale_label_for_value returns empty for blank value" do
    question = Struct.new(:answer_options_list).new([ "A", "B" ])
    assert_equal "", scale_label_for_value(question, "")
  end

  test "scale_label_for_value resolves numeric index labels" do
    question = Struct.new(:answer_options_list).new([ "Low", "High" ])
    assert_equal "Low", scale_label_for_value(question, "1")
    assert_equal "High", scale_label_for_value(question, 2)
  end

  test "scale_label_for_value falls back when index out of range or non-numeric" do
    question = Struct.new(:answer_options_list).new([ "Low", "High" ])
    assert_equal "3", scale_label_for_value(question, "3")
    assert_equal "Other", scale_label_for_value(question, "Other")
  end

  test "tailwind_stylesheet_tag returns fallback link when asset pipeline raises" do
    fake_asset = Struct.new(:digested_path).new("tailwind-abc123.css")
    load_path = Object.new
    load_path.define_singleton_method(:find) do |name|
      name == "tailwind.css" ? fake_asset : nil
    end
    fake_assets = Struct.new(:load_path).new(load_path)

    self.stub(:stylesheet_link_tag, ->(*) { raise StandardError, "boom" }) do
      Rails.application.stub(:assets, fake_assets) do
        html = tailwind_stylesheet_tag
        assert html
        assert_includes html, "tailwind-abc123.css"
        assert_includes html, "rel=\"stylesheet\""
      end
    end
  end

  test "tailwind_stylesheet_tag returns nil when fallback asset missing" do
    self.stub(:stylesheet_link_tag, ->(*) { raise StandardError, "boom" }) do
      Rails.application.stub(:assets, nil) do
        assert_nil tailwind_stylesheet_tag
      end
    end
  end
end
