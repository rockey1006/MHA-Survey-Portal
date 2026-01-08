require "active_support/core_ext/numeric/time"

# Represents the assignment of a survey to a specific student (and optional advisor).
class SurveyAssignment < ApplicationRecord
  self.ignored_columns += %w[due_date]

  belongs_to :survey
  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :advisor, foreign_key: :advisor_id, primary_key: :advisor_id, optional: true

  after_commit :enqueue_assigned_notification, on: :create

  validates :student, presence: true
  validates :survey, presence: true
  validates :assigned_at, presence: true
  validates :student_id, uniqueness: { scope: :survey_id }

  scope :recent, -> { order(assigned_at: :desc) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :closes_after, ->(time) { where("available_until > ?", time) }
  scope :closes_before, ->(time) { where("available_until <= ?", time) }
  scope :closes_between, ->(start_time, end_time) { where(available_until: start_time..end_time) }

  # @return [User] the user record backing the student
  def recipient_user
    student&.user
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # @return [User, nil] the advisor's user record
  def advisor_user
    advisor&.user
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # Marks the assignment as completed if not already done.
  #
  # @return [void]
  def mark_completed!(timestamp = Time.current)
    update!(completed_at: timestamp) unless completed_at?
  end

  # @return [Boolean] true when the assignment has passed its availability window without completion
  def overdue?(reference_time = Time.current)
    available_until.present? && completed_at.nil? && available_until < reference_time
  end

  # @return [Boolean] true when current time is within the availability window
  def available_now?(reference_time = Time.current)
    return false if available_from.present? && reference_time < available_from
    return false if available_until.present? && reference_time > available_until

    true
  end

  # @return [Symbol] :not_yet, :closed, or :open
  def availability_status(reference_time = Time.current)
    return :not_yet if available_from.present? && reference_time < available_from
    return :closed if available_until.present? && reference_time > available_until

    :open
  end

  # For submitted surveys, revisions are allowed while the assignment remains
  # within the availability window.
  def can_edit_now?(reference_time = Time.current)
    return false unless available_now?(reference_time)

    if completed_at?
      return true if available_until.blank?
      return available_until >= reference_time
    end

    true
  end

  # @return [Boolean] true when the assignment closes within the specified window
  def closes_within?(window:, reference_time: Time.current)
    return false unless available_until.present? && completed_at.nil?

    available_until <= reference_time + window && available_until >= reference_time
  end

  private

  # Pushes the "assigned" notification onto the queue once the assignment
  # transaction commits, ensuring the student sees a new-notification badge.
  #
  # @return [void]
  def enqueue_assigned_notification
    return unless recipient_user

    SurveyNotificationJob.perform_later(event: :assigned, survey_assignment_id: id)
  end
end
