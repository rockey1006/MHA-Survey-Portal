class SurveyAssignment < ApplicationRecord
  belongs_to :survey

  validates :track, presence: true, length: { maximum: 255 }
  validates :track, uniqueness: { scope: :survey_id, case_sensitive: false }

  scope :ordered, -> { order(:track) }
end
