# frozen_string_literal: true

class SurveyLegendComponent < ViewComponent::Base
  def initialize(legend:)
    @legend = legend
  end

  def render?
    @legend&.body.present?
  end

  private

  attr_reader :legend

  def title
    legend.title.presence || "Rating Scale Reference"
  end

  def sections
    @sections ||= begin
      text = legend.body.to_s
      lines = text.gsub("\r\n", "\n").gsub("\r", "\n").lines.map(&:rstrip)

      parsed = []
      current = nil

      i = 0
      while i < lines.length
        line = lines[i].to_s.strip

        if line.empty? || line.match?(/\A-+\z/)
          i += 1
          next
        end

        if line.start_with?("-")
          current ||= { heading: nil, paragraphs: [], items: [] }
          current[:items] << line.sub(/\A-\s*/, "")
          i += 1
          next
        end

        # Treat as a section heading only when it is followed by an underline divider (-----)
        j = i + 1
        j += 1 while j < lines.length && lines[j].to_s.strip.empty?

        if j < lines.length && lines[j].to_s.strip.match?(/\A-+\z/)
          parsed << current if current
          current = { heading: line, paragraphs: [], items: [] }
          i = j + 1
          next
        end

        current ||= { heading: nil, paragraphs: [], items: [] }
        current[:paragraphs] << line
        i += 1
      end

      parsed << current if current
      parsed
    end
  end
end
