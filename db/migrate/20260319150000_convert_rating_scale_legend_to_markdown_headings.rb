# frozen_string_literal: true

class ConvertRatingScaleLegendToMarkdownHeadings < ActiveRecord::Migration[8.0]
  LEGEND_TITLE = "Rating Scale Reference"

  HEADING_PAIRS = {
    "Mastery (5)" => "----------",
    "Experienced (4)" => "-------------",
    "Capable (3)" => "----------",
    "Emerging (2)" => "----------",
    "Beginner (1)" => "----------",
    "Not able to assess (0) [Advisor Only]" => "---------------------"
  }.freeze

  class SurveyLegend < ActiveRecord::Base
    self.table_name = "survey_legends"
  end

  def up
    return unless table_exists?(:survey_legends)

    say_with_time "Converting rating scale legends to markdown heading format" do
      target_scope.find_each do |legend|
        converted = setext_to_atx(legend.body.to_s)
        next if converted == legend.body.to_s

        legend.update_column(:body, converted)
      end
    end
  end

  def down
    return unless table_exists?(:survey_legends)

    say_with_time "Reverting rating scale legends to setext heading format" do
      target_scope.find_each do |legend|
        reverted = atx_to_setext(legend.body.to_s)
        next if reverted == legend.body.to_s

        legend.update_column(:body, reverted)
      end
    end
  end

  private

  def target_scope
    SurveyLegend.where(title: LEGEND_TITLE)
  end

  def setext_to_atx(text)
    lines = normalize_lines(text)
    output = []

    i = 0
    while i < lines.length
      heading = lines[i].to_s.strip
      underline = lines[i + 1].to_s.strip

      if HEADING_PAIRS[heading] == underline
        output << "## #{heading}"
        i += 2
      else
        output << lines[i]
        i += 1
      end
    end

    output.join("\n")
  end

  def atx_to_setext(text)
    lines = normalize_lines(text)
    output = lines.map do |line|
      stripped = line.to_s.strip
      heading = stripped.sub(/\A##\s+/, "")

      if stripped.start_with?("## ") && HEADING_PAIRS.key?(heading)
        "#{heading}\n#{HEADING_PAIRS[heading]}"
      else
        line
      end
    end

    output.join("\n")
  end

  def normalize_lines(text)
    text.to_s.gsub("\r\n", "\n").gsub("\r", "\n").split("\n", -1)
  end
end
