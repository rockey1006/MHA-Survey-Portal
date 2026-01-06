# Per-survey legend content displayed alongside the student survey form.
# Intended to be editable by admins in future iterations.
class SurveyLegend < ApplicationRecord
  belongs_to :survey

  validates :survey_id, uniqueness: true
end
