# Stores advisor feedback summaries linked to students and surveys.
class Feedback < ApplicationRecord
  self.table_name = "feedback"

  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :advisor, foreign_key: :advisor_id, primary_key: :advisor_id
  belongs_to :category
  belongs_to :survey

  validates :average_score, numericality: true, allow_nil: true
  validates :survey_id, uniqueness: true
end
