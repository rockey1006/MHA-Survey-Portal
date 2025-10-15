class Category < ApplicationRecord
  has_many :category_questions, dependent: :destroy
  has_many :questions, through: :category_questions
  has_many :survey_questions, through: :questions
  has_many :surveys, -> { distinct }, through: :survey_questions
  has_many :feedbacks, foreign_key: :category_id, class_name: "Feedback"

  validates :name, presence: true
end
