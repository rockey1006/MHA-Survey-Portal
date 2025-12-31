require "test_helper"

class SurveyLegendComponentTest < ActiveSupport::TestCase
  test "render? is false when legend body blank" do
    legend = SurveyLegend.new(title: "Any", body: "")
    component = SurveyLegendComponent.new(legend: legend)

    assert_equal false, component.render?
  end

  test "title falls back when legend title missing" do
    legend = SurveyLegend.new(title: nil, body: "Something")
    component = SurveyLegendComponent.new(legend: legend)

    assert_equal "Rating Scale Reference", component.send(:title)
  end

  test "sections parses headings, paragraphs, and list items" do
    body = <<~TEXT
      Heading A
      -----
      First paragraph.
      - Item 1
      - Item 2

      Heading B
      -----
      Second paragraph.
    TEXT

    legend = SurveyLegend.new(title: "Scale", body: body)
    component = SurveyLegendComponent.new(legend: legend)

    sections = component.send(:sections)
    assert_equal 2, sections.size

    assert_equal "Heading A", sections[0][:heading]
    assert_includes sections[0][:paragraphs], "First paragraph."
    assert_equal [ "Item 1", "Item 2" ], sections[0][:items]

    assert_equal "Heading B", sections[1][:heading]
    assert_includes sections[1][:paragraphs], "Second paragraph."
  end

  test "sections ignores divider-only lines and blank lines" do
    body = "\n-----\n- Item\n\n"
    legend = SurveyLegend.new(title: nil, body: body)
    component = SurveyLegendComponent.new(legend: legend)

    sections = component.send(:sections)
    assert_equal 1, sections.size
    assert_equal [ "Item" ], sections[0][:items]
  end
end
