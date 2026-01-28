module Assignments
  # Provides admins and advisors with read access to survey definitions and lets
  # them assign/unassign surveys to students.
  class SurveysController < BaseController
    before_action :set_survey, only: %i[show assign assign_all unassign]

    # Lists surveys with their categories and questions.
    def index
      @surveys = Survey.includes(:categories, :questions).order(created_at: :desc)
    end

    # Shows survey metadata and the list of students eligible for assignment.
    def show
      @students = assignable_students

      track_key =
        if @survey.respond_to?(:track) && @survey.track.present?
          @survey.track.to_s.downcase
        else
          t = @survey.title.to_s.downcase
          t.include?("executive") ? "executive" : (t.include?("residential") ? "residential" : nil)
        end

      if track_key.present? && Student.tracks.key?(track_key)
        @students = @students.where(track: Student.tracks[track_key])
      end

      @track_options = ProgramTrack.names
      @year_options = assignable_students.where.not(program_year: nil).distinct.order(:program_year).pluck(:program_year)
      @default_track_label = track_key.present? ? Student.tracks[track_key] : nil

      student_ids = @students.pluck(:student_id)
      @assignments_by_student_id =
        SurveyAssignment
          .where(survey_id: @survey.id, student_id: student_ids)
          .select(:id, :student_id, :assigned_at, :available_from, :available_until, :completed_at)
          .index_by(&:student_id)

      @assigned_student_ids = @assignments_by_student_id.keys.to_set
    end

    # Assigns the selected survey to a single student.
    def assign
      student = assignable_students.find_by!(student_id: params[:student_id])

      ActiveRecord::Base.transaction do
        @survey.questions.find_each do |question|
          StudentQuestion.find_or_create_by!(student_id: student.student_id, question_id: question.id) do |record|
            record.advisor_id = current_advisor_profile&.advisor_id
          end
        end

        upsert_assignment_for(student)
      end

      redirect_to assignments_surveys_path,
                  notice: "Assigned '#{@survey.title}' to #{student.full_name || student.user.email} at #{timestamp_str}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to assignments_survey_path(@survey), alert: e.record.errors.full_messages.to_sentence
    end

    # Assigns the survey to all eligible students in the survey's track.
    def assign_all
      students = assignable_students
      track_filter = params[:track].presence
      year_filter = params[:program_year].presence

      if track_filter.present?
        canonical = ProgramTrack.canonical_key(track_filter)
        track_label = ProgramTrack.name_for_key(canonical) || track_filter.to_s.strip
        students = students.where(track: track_label)
      end

      if year_filter.present?
        students = students.where(program_year: year_filter.to_i)
      end

      if track_filter.blank? && year_filter.blank?
        students = eligible_students_for_track
      end

      if students.blank?
        redirect_to assignments_survey_path(@survey),
                    alert: "No students available for the selected assignment group."
        return
      end

      created_count = 0

      ActiveRecord::Base.transaction do
        students.find_each do |student|
          @survey.questions.find_each do |question|
            StudentQuestion.find_or_create_by!(student_id: student.student_id, question_id: question.id) do |record|
              record.advisor_id = current_advisor_profile&.advisor_id
            end
          end

          _assignment, created = upsert_assignment_for(student)
          created_count += 1 if created
        end
      end

      group_label = []
      group_label << (track_filter.present? ? track_filter.to_s.strip : (survey_track_key&.titleize || "selected track"))
      group_label << "Class of #{year_filter}" if year_filter.present?
      redirect_to assignments_surveys_path,
          notice: "Assigned '#{@survey.title}' to #{created_count} student#{'s' unless created_count == 1} in #{group_label.compact.join(' • ')} at #{timestamp_str}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to assignments_survey_path(@survey), alert: e.record.errors.full_messages.to_sentence
    end

    # Unassigns the survey from a single student.
    def unassign
      student = assignable_students.find_by!(student_id: params[:student_id])

      assignment = SurveyAssignment.find_by(survey_id: @survey.id, student_id: student.student_id)
      if assignment&.completed_at?
        redirect_to assignments_survey_path(@survey),
                    alert: "Cannot unassign a completed survey for #{student.full_name || student.user.email}."
        return
      end

      scope = StudentQuestion.where(
        student_id: student.student_id,
        question_id: @survey.questions.select(:id)
      )

      if scope.exists?
        ActiveRecord::Base.transaction do
          scope.delete_all
          assignment&.destroy!
          Notification.deliver!(
            user: student.user,
            title: "Survey Unassigned",
            message: "#{current_user.name} removed '#{@survey.title}' from your assignments.",
            notifiable: @survey
          )
        end
        redirect_to assignments_survey_path(@survey),
                    notice: "Unassigned '#{@survey.title}' from #{student.full_name || student.user.email} at #{timestamp_str}."
      else
        redirect_to assignments_survey_path(@survey), alert: "No assignment found for that student."
      end
    end

    private

    def set_survey
      @survey = Survey.find(params[:id])
      @survey_number = @survey.id
    end

    def assignable_students
      if current_user.role_admin?
        Student.includes(:user)
      else
        (current_advisor_profile&.advisees || Student.none).includes(:user)
      end
    end

    def eligible_students_for_track
      scope = assignable_students
      key = survey_track_key
      return scope.none unless key.present? && Student.tracks.key?(key)

      scope.where(track: Student.tracks[key])
    end

    def survey_track_key
      @survey_track_key ||= begin
        if @survey.respond_to?(:track) && @survey.track.present?
          @survey.track.to_s.downcase
        else
          t = @survey.title.to_s.downcase
          t.include?("executive") ? "executive" : (t.include?("residential") ? "residential" : nil)
        end
      end
    end

    # Ensures a SurveyAssignment exists for the student/survey pair.
    #
    # @param student [Student]
    # @return [Array<(SurveyAssignment, Boolean)>] record and flag indicating creation
    def upsert_assignment_for(student)
      assignment = SurveyAssignment.find_or_initialize_by(
        survey_id: @survey.id,
        student_id: student.student_id
      )

      created = assignment.new_record?
      assignment.manual = true if assignment.respond_to?(:manual=)
      assignment.advisor_id ||= current_advisor_profile&.advisor_id
      assignment.assigned_at ||= Time.current

      default_available_from = @survey.available_from
      default_available_until = @survey.available_until

      if SurveyOffering.data_source_ready? && student.track.present? && student.program_year.present?
        offerings = SurveyOffering.for_student(track_key: student.track, class_of: student.program_year)
                                 .where(survey_id: @survey.id)
        if offerings.exists?
          exact = offerings.find { |row| row.class_of.present? && row.class_of.to_i == student.program_year.to_i }
          offering = exact || offerings.first
          default_available_from = offering.available_from if offering.available_from.present?
          default_available_until = offering.available_until if offering.available_until.present?
        end
      end

      assignment.available_from ||= default_available_from
      assignment.available_until ||= default_available_until

      if (available_from = parsed_available_from)
        assignment.available_from = available_from
      end

      if (available_until = parsed_available_until)
        assignment.available_until = available_until
      end

      assignment.completed_at = nil if created
      assignment.save! if assignment.new_record? || assignment.changed?

      [ assignment, created ]
    end

    def parsed_available_from
      return @parsed_available_from if instance_variable_defined?(:@parsed_available_from)

      raw_value = params[:available_from].presence
      @parsed_available_from = begin
        raw_value ? Time.zone.parse(raw_value) : nil
      rescue ArgumentError
        nil
      end
    end

    def parsed_available_until
      return @parsed_available_until if instance_variable_defined?(:@parsed_available_until)

      raw_value = params[:available_until].presence
      @parsed_available_until = begin
        raw_value ? Time.zone.parse(raw_value) : nil
      rescue ArgumentError
        nil
      end
    end

    def timestamp_str
      I18n.l(Time.current, format: :long)
    rescue I18n::MissingTranslationData, I18n::InvalidLocale
      Time.current.to_fs(:long)
    end
  end
end
