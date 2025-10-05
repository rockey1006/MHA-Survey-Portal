class QuestionResponse < ApplicationRecord
  self.primary_key = :questionresponse_id

  belongs_to :survey_response, foreign_key: :surveyresponse_id, primary_key: :surveyresponse_id
  belongs_to :question

  validates :survey_response, presence: true
  validates :question, presence: true
  validates :question_id, uniqueness: { scope: :surveyresponse_id }

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
end
