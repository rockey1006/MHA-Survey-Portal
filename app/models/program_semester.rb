# Tracks program semesters (e.g., "Fall 2025") and identifies which one is current.
class ProgramSemester < ApplicationRecord
  DEFAULT_CURRENT_NAME = "Fall 2025".freeze
  before_validation :normalize_name
  after_commit :ensure_single_current!, if: -> { saved_change_to_current? && current? }
  after_destroy :assign_fallback_current!

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(created_at: :asc) }

  # @return [ProgramSemester, nil]
  def self.current
    find_by(current: true) || find_by_name_case_insensitive(DEFAULT_CURRENT_NAME) || ordered.last
  end

  # @return [String, nil]
  def self.current_name
    current&.name
  end

  private

  def normalize_name
    self.name = name.to_s.strip.squeeze(" ")
    return if name.blank?

    tokens = name.split(/\s+/)
    self.name = tokens.map.with_index do |token, index|
      if token.match?(/^\d+$/)
        token
      elsif index.zero?
        token.capitalize
      else
        token
      end
    end.join(" ")
  end

  def ensure_single_current!
    ProgramSemester.where.not(id: id).update_all(current: false)
  end

  def assign_fallback_current!
    return if ProgramSemester.where(current: true).exists?

    fallback = ProgramSemester.ordered.last
    fallback&.update_column(:current, true)
  end

  def self.find_by_name_case_insensitive(value)
    return if value.blank?

    where("LOWER(name) = ?", value.downcase).first
  end
end
