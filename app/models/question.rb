require "json"

# Survey prompt tied to a category, supporting multiple response types.
class Question < ApplicationRecord
  enum :question_type, {
    multiple_choice: "multiple_choice",
    dropdown: "dropdown",
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
      parsed.map do |entry|
        case entry
        when String
          entry
        else
          entry.to_s
        end
      end
    else
      raw.gsub(/[\[\]\"“”]/, "").split(",").map(&:strip).reject(&:empty?)
    end
  end

  # Returns a normalized list of [label, value] pairs for choice-style questions.
  #
  # Supports answer_options stored as:
  # - ["Yes", "No"]
  # - [["Mastery (5)", "5"], ...]
  # - [{"label":"Mastery (5)","value":"5"}, ...]
  #
  # @return [Array<Array(String, String)>]
  def answer_option_pairs
    raw = answer_options.to_s
    return [] if raw.blank?

    parsed = JSON.parse(raw) rescue nil
    list = parsed.is_a?(Array) ? parsed : answer_options_list

    Array(list).filter_map do |entry|
      case entry
      when Array
        next unless entry.size >= 2

        label = entry[0].to_s.strip
        value = entry[1].to_s.strip
        next if label.blank? || value.blank?

        [label, value]
      when Hash
        label = (entry["label"] || entry[:label]).to_s.strip
        value = (entry["value"] || entry[:value] || label).to_s.strip
        next if label.blank? || value.blank?

        [label, value]
      else
        str = entry.to_s.strip
        next if str.blank?

        [str, str]
      end
    end
  end

  # @return [Array<String>] values for choice-style questions.
  def answer_option_values
    answer_option_pairs.map { |(_label, value)| value }
  end

  # @return [Boolean] whether this question uses discrete choice options
  def choice_question?
    question_type_multiple_choice? || question_type_dropdown?
  end

  private

  def ensure_question_order
    return if question_order.present?

    self.question_order = (category&.questions&.maximum(:question_order) || 0) + 1
  end
end
