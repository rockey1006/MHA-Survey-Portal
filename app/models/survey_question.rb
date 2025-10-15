class SurveyQuestion < ApplicationRecord
  belongs_to :survey
  belongs_to :question

  validates :question_id, uniqueness: { scope: :survey_id }
end
