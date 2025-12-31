# frozen_string_literal: true

# Reconciles survey assignments for all relevant students after a survey-level
# change (e.g., due date adjustments).
class ReconcileSurveyAssignmentsJob < ApplicationJob
  queue_as :default

  # @param survey_id [Integer]
  def perform(survey_id:)
    survey = Survey.find_by(id: survey_id)
    return unless survey

    tracks = survey.track_list
    return if tracks.blank?

    Student.where(track: tracks).find_each do |student|
      SurveyAssignments::AutoAssigner.call(student: student)
    end
  end
end
