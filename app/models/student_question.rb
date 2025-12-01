require "json"

# Represents a student's response to a single survey question.
class StudentQuestion < ApplicationRecord
  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :advisor, optional: true, foreign_key: :advisor_id, primary_key: :advisor_id
  belongs_to :question

  validates :student, presence: true
  validates :question, presence: true
  validates :question_id, uniqueness: { scope: :student_id }
  validate :validate_evidence_link, if: :evidence_question?

  before_save :normalize_response_value

  # Pattern used to validate Google-hosted links (Drive, Docs, Sites, etc.) for evidence responses.
  GOOGLE_URL_REGEX = %r{\Ahttps?://(?:(?:drive|docs|sites)\.google\.com|(?:[a-z0-9-]+\.)?googleusercontent\.com)(?:/|$)\S*}i

  # Returns the deserialized answer for the question, handling stored JSON.
  #
  # @return [Object, nil]
  def answer
    raw = read_attribute(:response_value)
    return nil if raw.nil?

    if raw.is_a?(String) && (raw.strip.start_with?("{") || raw.strip.start_with?("["))
      begin
        JSON.parse(raw)
      rescue JSON::ParserError
        raw
      end
    else
      raw
    end
  end

  # Serializes the provided value into the `response_value` column.
  #
  # @param val [Object]
  # @return [void]
  def answer=(val)
    if val.is_a?(String)
      write_attribute(:response_value, val)
    else
      write_attribute(:response_value, val.to_json)
    end
  end

  private

  def evidence_question?
    question.present? && question.question_type == "evidence"
  end

  def normalize_response_value
    current = read_attribute(:response_value)
    write_attribute(:response_value, current.strip) if current.is_a?(String)
  end

  def validate_evidence_link
    val = read_attribute(:response_value)
    return if val.blank?

    link_str = nil
    if val.is_a?(String)
      stripped = val.strip
      if stripped.start_with?("{")
        begin
          parsed = JSON.parse(stripped) rescue nil
          link_str = parsed.is_a?(Hash) ? parsed["link"].to_s : stripped
        rescue JSON::ParserError
          link_str = stripped
        end
      else
        link_str = stripped
      end
    else
      # Non-string stored (unlikely); best-effort cast
      link_str = val.to_s
    end

    return if link_str.blank?
    errors.add(:response_value, "must be a publicly shareable Google link") unless link_str =~ GOOGLE_URL_REGEX
  end
end
