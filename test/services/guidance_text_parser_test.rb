require "test_helper"

class GuidanceTextParserTest < ActiveSupport::TestCase
  test "sections returns empty array for blank input" do
    assert_equal [], GuidanceTextParser.new("").sections
    assert_equal [], GuidanceTextParser.new(nil).sections
    assert_equal [], GuidanceTextParser.new("\n\n").sections
  end

  test "parses titled paragraph sections" do
    input = <<~TEXT
      Getting Started
      --------
      First line.
      Second line.
    TEXT

    sections = GuidanceTextParser.new(input).sections
    assert_equal 1, sections.size

    section = sections.first
    assert_equal "Getting Started", section.title
    assert_equal [ "First line.", "Second line." ], section.paragraphs
    assert_equal [], section.bullets
  end

  test "parses titled bullet sections" do
    input = <<~TEXT
      Tips
      ---
      - One
      - Two
    TEXT

    sections = GuidanceTextParser.new(input).sections
    assert_equal 1, sections.size

    section = sections.first
    assert_equal "Tips", section.title
    assert_equal [], section.paragraphs
    assert_equal [ "One", "Two" ], section.bullets
  end

  test "splits multiple sections by blank lines" do
    input = <<~TEXT
      Tips
      ---
      - One

      Notes
      ---
      Remember this.
    TEXT

    sections = GuidanceTextParser.new(input).sections
    assert_equal 2, sections.size

    assert_equal "Tips", sections[0].title
    assert_equal [ "One" ], sections[0].bullets

    assert_equal "Notes", sections[1].title
    assert_equal [ "Remember this." ], sections[1].paragraphs
  end
end
