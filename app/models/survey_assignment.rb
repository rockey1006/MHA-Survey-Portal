require "active_support/core_ext/numeric/time"

# Represents the assignment of a survey to a specific student (and optional advisor).
class SurveyAssignment < ApplicationRecord
  belongs_to :survey
  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :advisor, foreign_key: :advisor_id, primary_key: :advisor_id, optional: true

  validates :student, presence: true
  validates :survey, presence: true
  validates :assigned_at, presence: true
  validates :student_id, uniqueness: { scope: :survey_id }

  scope :recent, -> { order(assigned_at: :desc) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :due_after, ->(time) { where("due_date > ?", time) }
  scope :due_before, ->(time) { where("due_date <= ?", time) }
  scope :due_between, ->(start_time, end_time) { where(due_date: start_time..end_time) }

  # @return [User] the user record backing the student
  def recipient_user
    student.user
  end

  # @return [User, nil] the advisor's user record
  def advisor_user
    advisor&.user
  end

  # Marks the assignment as completed if not already done.
  #
  # @return [void]
  def mark_completed!(timestamp = Time.current)
    update!(completed_at: timestamp) unless completed_at?
  end

  # @return [Boolean] true when the assignment has passed its due date without completion
  def overdue?(reference_time = Time.current)
    due_date.present? && completed_at.nil? && due_date < reference_time
  end

  # @return [Boolean] true when the assignment is due within the specified window
  def due_within?(window:, reference_time: Time.current)
    return false unless due_date.present? && completed_at.nil?

    due_date <= reference_time + window && due_date >= reference_time
  end
end
