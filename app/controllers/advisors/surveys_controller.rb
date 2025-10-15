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

      redirect_to advisors_surveys_path, notice: "Assigned '#{@survey.title}' to #{student.full_name || student.user.email}."
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
