# frozen_string_literal: true

class GuidanceTextParser
  Section = Struct.new(:title, :paragraphs, :bullets, keyword_init: true)

  def initialize(text)
    @text = text.to_s
  end

  def sections
    normalized = @text.strip
    return [] if normalized.blank?

    normalized
      .split(/\r?\n\r?\n+/)
      .map { |chunk| parse_section(chunk) }
      .compact
  end

  private

  def parse_section(chunk)
    lines = chunk.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
    return nil if lines.empty?

    title = nil
    if lines.length >= 2 && lines[1].match?(/\A[-]{2,}\z/)
      title = lines.shift
      lines.shift
    end

    if lines.present? && lines.all? { |line| line.start_with?("- ") }
      bullets = lines.map { |line| line.sub(/\A-\s*/, "") }
      Section.new(title:, paragraphs: [], bullets:)
    else
      Section.new(title:, paragraphs: lines, bullets: [])
    end
  end
end
