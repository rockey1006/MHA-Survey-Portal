class Survey < ApplicationRecord
  validates :title, presence: true
  validates :semester, presence: true

  has_many :survey_questions, dependent: :destroy
  has_many :questions, through: :survey_questions
  has_many :category_questions, through: :questions
  has_many :categories, -> { distinct }, through: :category_questions
  has_many :student_questions, through: :questions
  has_many :feedbacks, foreign_key: :survey_id, class_name: "Feedback", dependent: :destroy

  scope :ordered, -> { order(:id) }
end
