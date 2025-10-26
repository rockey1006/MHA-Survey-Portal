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

  # Pattern used to validate Google Drive links for evidence responses.
  DRIVE_URL_REGEX = %r{\Ahttps?://(?:drive\.google\.com|docs\.google\.com)/(?:file/d/|drive/folders/|document/d/|spreadsheets/d/|forms/d/|open\?).+}i

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

    val_str = (val.is_a?(String) ? val : val.to_s).strip
    errors.add(:response_value, "must be a Google Drive file or folder link") unless val_str =~ DRIVE_URL_REGEX
  end
end
