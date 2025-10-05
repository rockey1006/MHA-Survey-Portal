class Feedback < ApplicationRecord
  self.table_name = "feedback"
  self.primary_key = :feedback_id

  belongs_to :advisor
  belongs_to :category
  belongs_to :survey_response, foreign_key: :surveyresponse_id, primary_key: :surveyresponse_id

  validates :score, numericality: { allow_nil: true, only_integer: true }
  validates :advisor_id, uniqueness: { scope: [ :category_id, :surveyresponse_id ] }
end
