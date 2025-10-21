# Stores advisor feedback summaries linked to students and surveys.
class Feedback < ApplicationRecord
  self.table_name = "feedback"

  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :advisor, foreign_key: :advisor_id, primary_key: :advisor_id
  belongs_to :category
  belongs_to :survey

  validates :average_score, numericality: true, allow_nil: true
     # NOTE: previously we enforced uniqueness on survey_id which prevented
     # storing multiple per-category feedback rows for the same survey. That
     # constraint is enforced at a composite level in the DB and/or via
     # application logic; allow multiple Feedback records per survey here.
end
