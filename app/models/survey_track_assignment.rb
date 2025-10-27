# Associates a survey with a program track (e.g., Residential cohort).
class SurveyTrackAssignment < ApplicationRecord
  belongs_to :survey

  validates :track, presence: true, length: { maximum: 255 }
  validates :track, uniqueness: { scope: :survey_id, case_sensitive: false }

  # @return [ActiveRecord::Relation<SurveyTrackAssignment>] assignments ordered by track
  scope :ordered, -> { order(:track) }
end
