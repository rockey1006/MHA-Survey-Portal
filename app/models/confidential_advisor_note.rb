# Stores advisor-only confidential notes scoped to a student + survey + advisor.
class ConfidentialAdvisorNote < ApplicationRecord
  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :survey
  belongs_to :advisor, foreign_key: :advisor_id, primary_key: :advisor_id
end
