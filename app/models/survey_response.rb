class SurveyResponse < ApplicationRecord
  enum :status, {
    not_started: "not_started",
    in_progress: "in_progress",
    submitted: "submitted",
    under_review: "under_review",
    approved: "approved"
  }, prefix: true

  belongs_to :survey, optional: true  
  belongs_to :student, optional: true
  belongs_to :advisor, optional: true
end
