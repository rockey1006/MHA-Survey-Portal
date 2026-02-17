# Tracks advisor feedback workflow state for a student survey pair.
class AdvisorFeedbackSubmission < ApplicationRecord
  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :survey
  belongs_to :advisor, foreign_key: :advisor_id, primary_key: :advisor_id

  validates :student_id, :survey_id, :advisor_id, presence: true
  validates :student_id, uniqueness: { scope: %i[survey_id advisor_id] }

  scope :submitted, -> { where.not(submitted_at: nil) }
end
