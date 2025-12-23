# Stores immutable snapshots of a student's survey answers at a point in time.
class SurveyResponseVersion < ApplicationRecord
  belongs_to :student, foreign_key: :student_id, primary_key: :student_id
  belongs_to :survey
  belongs_to :survey_assignment, optional: true

  validates :student_id, presence: true
  validates :survey_id, presence: true
  validates :event, presence: true
  validates :answers, presence: true

  scope :for_pair, ->(student_id:, survey_id:) { where(student_id: student_id, survey_id: survey_id) }
  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  class << self
    # Captures a snapshot of the current persisted StudentQuestion answers for
    # the given student/survey pair.
    #
    # @param student [Student]
    # @param survey [Survey]
    # @param assignment [SurveyAssignment, nil]
    # @param actor_user [User, nil]
    # @param event [String, Symbol]
    # @return [SurveyResponseVersion]
    def capture_current!(student:, survey:, assignment: nil, actor_user: nil, event:)
      question_ids = survey.questions.select(:id)
      responses = StudentQuestion
                    .where(student_id: student.student_id, question_id: question_ids)
                    .select(:question_id, :response_value, :updated_at, :created_at)

      answers = responses.each_with_object({}) do |record, memo|
        memo[record.question_id.to_s] = record.answer
      end

      create!(
        student_id: student.student_id,
        survey_id: survey.id,
        advisor_id: student.advisor_id,
        survey_assignment_id: assignment&.id,
        actor_user_id: actor_user&.id,
        actor_role: actor_user&.role,
        event: event.to_s,
        answers: answers
      )
    end
  end
end
