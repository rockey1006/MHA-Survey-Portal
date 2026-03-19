require "active_support/core_ext/numeric/time"

# Represents the assignment of a survey to a specific student (and optional advisor).
class SurveyAssignment < ApplicationRecord
  self.ignored_columns += %w[due_date]

  belongs_to :survey
  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :advisor, foreign_key: :advisor_id, primary_key: :advisor_id, optional: true
  has_many :survey_response_versions, dependent: :nullify

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

  # Filters to assignments whose effective availability window (assignment overrides survey)
  # includes the given time, or that have already been completed.
  scope :effective_available_at, ->(time) {
    joins(:survey).where(effective_availability_sql, now: time)
  }

  # Returns the SQL fragment used to filter by effective availability window.
  # Expects survey_assignments and surveys tables to be joined.
  # Includes completed assignments regardless of window.
  #
  # Effective from/until uses the assignment's value if set, falling back to the survey's.
  def self.effective_availability_sql
    <<~SQL.squish
      (
        (COALESCE(survey_assignments.available_from, surveys.available_from) IS NULL
          OR COALESCE(survey_assignments.available_from, surveys.available_from) <= :now)
        AND
        (COALESCE(survey_assignments.available_until, surveys.available_until) IS NULL
          OR COALESCE(survey_assignments.available_until, surveys.available_until) >= :now)
      )
      OR survey_assignments.completed_at IS NOT NULL
    SQL
  end

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

  # @return [Time, nil] the effective available_from, falling back to the survey's value
  def effective_available_from
    available_from || survey&.available_from
  end

  # @return [Time, nil] the effective available_until, falling back to the survey's value
  def effective_available_until
    available_until || survey&.available_until
  end

  # @return [Boolean] true when the assignment has passed its effective availability window without completion
  def overdue?(reference_time = Time.current)
    eff_until = effective_available_until
    eff_until.present? && completed_at.nil? && eff_until < reference_time
  end

  # @return [Boolean] true when current time is within the effective availability window
  def available_now?(reference_time = Time.current)
    eff_from = effective_available_from
    eff_until = effective_available_until
    return false if eff_from.present? && reference_time < eff_from
    return false if eff_until.present? && reference_time > eff_until

    true
  end

  # @return [Symbol] :not_yet, :closed, or :open
  def availability_status(reference_time = Time.current)
    eff_from = effective_available_from
    eff_until = effective_available_until
    return :not_yet if eff_from.present? && reference_time < eff_from
    return :closed if eff_until.present? && reference_time > eff_until

    :open
  end

  # For submitted surveys, revisions are allowed while the assignment remains
  # within the effective availability window.
  def can_edit_now?(reference_time = Time.current)
    return false unless available_now?(reference_time)

    if completed_at?
      eff_until = effective_available_until
      return true if eff_until.blank?
      return eff_until >= reference_time
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
