require "json"

class Question < ApplicationRecord
  enum :question_type, {
    multiple_choice: "multiple_choice",
    scale: "scale",
    short_answer: "short_answer",
    evidence: "evidence"
  }, prefix: true

  has_many :survey_questions, dependent: :destroy
  has_many :surveys, through: :survey_questions
  has_many :category_questions, dependent: :destroy
  has_many :categories, through: :category_questions
  has_many :student_questions, dependent: :destroy
  has_many :students, through: :student_questions

  validates :question, presence: true
  validates :question_order, presence: true
  validates :question_type, presence: true, inclusion: { in: question_types.values }

  scope :ordered, -> { order(:question_order) }

  def answer_options_list
    raw = answer_options.to_s
    return [] if raw.blank?

    parsed = JSON.parse(raw) rescue nil
    if parsed.is_a?(Array)
      parsed
    else
      raw.gsub(/[\[\]\"“”]/, "").split(",").map(&:strip).reject(&:empty?)
    end
  end
end
