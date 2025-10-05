module Advisors
  class SurveysController < BaseController
    before_action :set_survey, only: %i[show assign]

    def index
      @surveys = Survey.includes(:categories, :questions).order(:created_at)
    end

    def show
      @survey_number = Survey.order(:created_at).pluck(:id).index(@survey.id)&.next || 1
      @students = assignable_students
    end

    def assign
      student = assignable_students.find_by!(student_id: params[:student_id])

      survey_response = SurveyResponse.find_or_initialize_by(
        survey_id: @survey.id,
        student_id: student.student_id
      )

      survey_response.advisor_id ||= current_advisor_profile&.advisor_id
      survey_response.status ||= SurveyResponse.statuses[:not_started]
      survey_response.save!

      redirect_to advisors_surveys_path, notice: "Assigned '#{@survey.title}' to #{student.full_name || student.email}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to advisors_survey_path(@survey), alert: e.record.errors.full_messages.to_sentence
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
  end
end
