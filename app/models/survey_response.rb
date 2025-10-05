class SurveyResponse < ApplicationRecord
  self.primary_key = :surveyresponse_id

  enum :status, {
    not_started: "Not Started",
    in_progress: "In Progress",
    submitted: "Submitted",
    under_review: "Under Review",
    approved: "Approved"
  }, prefix: true

  belongs_to :survey
  belongs_to :student
  belongs_to :advisor, optional: true

  has_many :question_responses, foreign_key: :surveyresponse_id, dependent: :destroy
  has_many :feedbacks, foreign_key: :surveyresponse_id, dependent: :destroy, class_name: "Feedback"

  scope :for_student, ->(student_id) { where(student_id: student_id) }
  scope :pending, -> { where(status: [ statuses[:not_started], statuses[:in_progress], statuses[:under_review] ]) }
  scope :completed, -> { where(status: [ statuses[:submitted], statuses[:approved] ]) }

  def approval_pending?
    status_under_review? || status_submitted?
  end

  def answers
    question_responses.includes(:question).map do |response|
      question_text = response.question&.question
      next if question_text.blank?

      answer_value = response.answer
      answer_text = answer_value.is_a?(Array) ? answer_value.join(", ") : answer_value
      [ question_text, answer_text ]
    end.compact.to_h
  end
end
