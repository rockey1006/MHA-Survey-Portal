class Survey < ApplicationRecord
  validates :title, presence: true
  validates :semester, presence: true

  has_many :categories, dependent: :destroy
  has_many :questions, through: :categories
  has_many :survey_responses, foreign_key: :survey_id, dependent: :destroy
  has_many :students, through: :survey_responses
end
