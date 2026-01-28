# Stores advisor feedback summaries linked to students and surveys.
class Feedback < ApplicationRecord
  self.table_name = "feedback"

  COMMENTS_MAX_LENGTH = 1000

  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :advisor, foreign_key: :advisor_id, primary_key: :advisor_id
  # Keep category association for legacy records and for parts of the app
  # that still reference feedback.category
  belongs_to :category
  belongs_to :question, optional: true
  belongs_to :survey

  validates :average_score,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 5
            },
            allow_nil: true

  validates :comments, length: { maximum: COMMENTS_MAX_LENGTH }, allow_nil: true
  # NOTE: previously we enforced uniqueness on survey_id which prevented
  # storing multiple per-category feedback rows for the same survey. That
  # constraint is enforced at a composite level in the DB and/or via
  # application logic; allow multiple Feedback records per survey here.

  after_commit :enqueue_feedback_received_notification, on: [ :create, :update ]

  private

  def enqueue_feedback_received_notification
    changed_keys = previous_changes.keys
    return unless (changed_keys & %w[average_score comments]).any?

    SurveyNotificationJob.perform_later(event: :feedback_received, feedback_id: id)
  rescue StandardError => e
    Rails.logger.warn("Feedback notification enqueue failed for Feedback #{id}: #{e.class} - #{e.message}")
  end
end
