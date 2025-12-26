# frozen_string_literal: true

module SurveyAssignments
  # Ensures a student's survey assignments mirror the surveys associated with
  # their current track selection and program year. When either value is blank,
  # the auto assigner leaves the assignment list untouched so that a first-time
  # login does not receive surveys prematurely.
  class AutoAssigner
    # @param student [Student]
    # @param track [String, nil]
    # @param program_year [Integer, String, nil]
    # @return [void]
    def self.call(student:, track: nil, program_year: nil)
      new(student:, track:, program_year:).call
    end

    def initialize(student:, track: nil, program_year: nil)
      @student = student
      @track = (track.presence || student&.track).to_s.strip
      @program_year = program_year.presence || student&.program_year
    end

    def call
      return unless student

      if track.blank? || program_year.blank?
        # Track selection not available yet; remove any outdated managed
        # assignments so that onboarding students start with a clean slate.
        remove_managed_assignments!(allowed_ids: [])
        reset_student_assignment_cache!
        return
      end

      surveys = surveys_for_track
      active_ids = surveys.map(&:id)

      ActiveRecord::Base.transaction do
        remove_managed_assignments!(allowed_ids: active_ids)
        assign_missing_surveys!(surveys)
      end

      reset_student_assignment_cache!
    end

    private

    attr_reader :student, :track, :program_year

    def surveys_for_track
      current_semester = ProgramSemester.current&.name.to_s.strip
      if current_semester.blank?
        current_semester = ProgramSemester.ordered.last&.name.to_s.strip
      end

      return Survey.none if current_semester.blank?

      Survey.active
        .joins(:program_semester)
        .where("LOWER(program_semesters.name) = ?", current_semester.downcase)
            .joins(:track_assignments)
            .where("LOWER(survey_track_assignments.track) = ?", track.downcase)
            .distinct
    end

    def remove_managed_assignments!(allowed_ids: [])
      scope = assignment_scope.joins(survey: :track_assignments).distinct
      scope = scope.where.not(survey_id: allowed_ids) if allowed_ids.present?
      scope = scope.where(completed_at: nil) # completed assignments double as an audit log
      scope.find_each(&:destroy!)
    end

    def assign_missing_surveys!(surveys)
      existing = assignment_scope.index_by(&:survey_id)

      surveys.each do |survey|
        assignment = existing[survey.id] || SurveyAssignment.new(student_id: student.student_id, survey: survey)
        assignment.advisor_id ||= student.advisor_id
        assignment.assigned_at ||= Time.zone.now
        if assignment.respond_to?(:due_date) && survey.respond_to?(:due_date)
          desired_due_date = survey.due_date

          if desired_due_date.present?
            assignment.due_date = desired_due_date if assignment.due_date.blank? || assignment.due_date.to_date != desired_due_date.to_date
          end
        end

        assignment.save! if assignment.new_record? || assignment.changed?
      end
    end

    def assignment_scope
      SurveyAssignment.where(student_id: student.student_id)
    end

    def reset_student_assignment_cache!
      association = student.association(:survey_assignments)
      association.reset if association.loaded?
    end
  end
end
