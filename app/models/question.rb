require "json"

class Question < ApplicationRecord
  enum :question_type, {
    multiple_choice: "multiple_choice",
    scale: "scale",
    short_answer: "short_answer",
    evidence: "evidence"
  }, prefix: true

  belongs_to :category
  has_many :student_questions, dependent: :destroy
  has_many :students, through: :student_questions

  alias_attribute :question, :question_text

  validates :category, presence: true
  validates :question_text, presence: true
  validates :question_order, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :question_type, presence: true, inclusion: { in: question_types.values }

  scope :ordered, -> { order(:question_order) }

  before_validation :ensure_question_order

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

  private

  def ensure_question_order
    return if question_order.present?

    self.question_order = (category&.questions&.maximum(:question_order) || 0) + 1
  end
end
