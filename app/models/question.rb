require "json"

# Survey prompt tied to a category, supporting multiple response types.
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
  alias_attribute :required, :is_required

  validates :category, presence: true
  validates :question_text, presence: true
  validates :question_order, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :question_type, presence: true, inclusion: { in: question_types.values }

  # @return [ActiveRecord::Relation<Question>] questions ordered for display
  scope :ordered, -> { order(:question_order) }

  before_validation :ensure_question_order

  # @return [Boolean] whether the question is required
  def required?
    is_required?
  end

  # Parses the serialized answer options into an array, gracefully handling
  # legacy formats.
  #
  # @return [Array<String>]
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
