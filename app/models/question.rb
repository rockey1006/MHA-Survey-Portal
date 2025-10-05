class Question < ApplicationRecord
  self.primary_key = :question_id

  enum :question_type, {
    multiple_choice: "multiple_choice",
    scale: "scale",
    short_answer: "short_answer",
    evidence: "evidence"
  }, prefix: true

  belongs_to :category
  has_many :question_responses, foreign_key: :question_id, dependent: :destroy

  validates :question, presence: true
  validates :question_order, presence: true
  validates :question_type, presence: true, inclusion: { in: question_types.values }
end
