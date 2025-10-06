class QuestionResponse < ApplicationRecord
  self.primary_key = :questionresponse_id

  belongs_to :survey_response, foreign_key: :surveyresponse_id, primary_key: :surveyresponse_id
  belongs_to :question

  validates :survey_response, presence: true
  validates :question, presence: true
  validates :question_id, uniqueness: { scope: :surveyresponse_id }

  # Validate evidence links when the associated question is of type 'evidence'
  validate :validate_evidence_link, if: :evidence_question?

  # Normalize answer on save (trim whitespace) and ensure validation runs
  before_save :normalize_answer

  # Preserve JSON/string storage for answers to accommodate multi-select values
  def answer
    raw = read_attribute(:answer)
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

  def answer=(val)
    if val.is_a?(String)
      write_attribute(:answer, val)
    else
      write_attribute(:answer, val.to_json)
    end
  end

  private

  # Returns true when the associated question is an evidence type
  def evidence_question?
    question.present? && question.question_type == "evidence"
  end

  # Strip surrounding whitespace/newlines from stored answer (if string)
  def normalize_answer
    a = read_attribute(:answer)
    if a.is_a?(String)
      write_attribute(:answer, a.strip)
    end
  end

  # Simple Google Drive link validator; accepts common file/folder URL patterns
  DRIVE_URL_REGEX = %r{\Ahttps?://(?:drive\.google\.com|docs\.google\.com)/(?:file/d/|open\?|drive/folders/).+}i

  def validate_evidence_link
    val = read_attribute(:answer)
    return if val.blank?
    # If JSON stored, attempt to coerce to string
    val_str = val.is_a?(String) ? val : val.to_s
    unless val_str =~ DRIVE_URL_REGEX
      errors.add(:answer, "must be a Google Drive file or folder link")
    end
  end
end
