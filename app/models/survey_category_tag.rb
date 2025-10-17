# Tagging model connecting surveys to reusable categories.
class SurveyCategoryTag < ApplicationRecord
  belongs_to :survey
  belongs_to :category

  validates :category_id, presence: true
  validates :survey_id, uniqueness: { scope: :category_id }
end
