module Advisors
  # Provides advisors with read access to survey definitions and lets them
  # assign/unassign surveys to students in their cohort.
  class SurveysController < BaseController
    before_action :set_survey, only: %i[show assign assign_all unassign]

    # Lists surveys with their categories and questions for advisor review.
    def index
      @surveys = Survey.includes(:categories, :questions).order(:created_at)
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

      @assigned_student_ids = StudentQuestion
        .where(question_id: @survey.questions.select(:id))
        .distinct
        .pluck(:student_id)
        .to_set
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

        Notification.create!(
          notifiable: student,
          title: "New survey assigned",
          message: "#{current_user.name} assigned '#{@survey.title}' to you."
        )
      end

      redirect_to advisors_surveys_path,
                  notice: "Assigned '#{@survey.title}' to #{student.full_name || student.user.email} at #{timestamp_str}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to advisors_survey_path(@survey), alert: e.record.errors.full_messages.to_sentence
    end

    # Assigns the survey to all eligible students in the survey's track.
    def assign_all
      students = eligible_students_for_track

      if students.blank?
        redirect_to advisors_survey_path(@survey),
                    alert: "No students available in the #{survey_track_key&.titleize || 'selected'} track."
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

          Notification.create!(
            notifiable: student,
            title: "New survey assigned",
            message: "#{current_user.name} assigned '#{@survey.title}' to you."
          )

          created_count += 1
        end
      end

      redirect_to advisors_surveys_path,
                  notice: "Assigned '#{@survey.title}' to #{created_count} student#{'s' unless created_count == 1} in the #{survey_track_key.titleize} track at #{timestamp_str}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to advisors_survey_path(@survey), alert: e.record.errors.full_messages.to_sentence
    end

    # Unassigns the survey from a single student.
    def unassign
      student = assignable_students.find_by!(student_id: params[:student_id])

      scope = StudentQuestion.where(
        student_id: student.student_id,
        question_id: @survey.questions.select(:id)
      )

      if scope.exists?
        ActiveRecord::Base.transaction do
          scope.delete_all
          Notification.create!(
            notifiable: student,
            title: "Survey unassigned",
            message: "#{current_user.name} removed '#{@survey.title}' from your assignments."
          )
        end
        redirect_to advisors_survey_path(@survey),
                    notice: "Unassigned '#{@survey.title}' from #{student.full_name || student.user.email} at #{timestamp_str}."
      else
        redirect_to advisors_survey_path(@survey), alert: "No assignment found for that student."
      end
    end

    private

    def set_survey
      @survey = Survey.find(params[:id])
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
      key   = survey_track_key
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

    # Localized timestamp for flash messages
    def timestamp_str
      I18n.l(Time.current, format: :long)
    rescue I18n::MissingTranslationData, I18n::InvalidLocale
      Time.current.to_s(:long)
    end
  end
end
