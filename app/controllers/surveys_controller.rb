class SurveysController < ApplicationController
  before_action :set_survey, only: %i[show submit]

  def index
    @surveys = Survey.active.ordered
  end

  def show
    @category_groups = @survey.categories.includes(:questions).order(:id)
    @existing_answers = {}
    @computed_required = {}
    student = current_student

    if student
      responses = StudentQuestion
                    .where(student_id: student.student_id, question_id: @survey.questions.select(:id))
                    .includes(:question)

      responses.each do |response|
        @existing_answers[response.question_id] = response.answer
      end
    end

    @category_groups.each do |category|
      category.questions.each do |question|
        required = question.is_required?

        if !required && question.question_type_multiple_choice?
          options = question.answer_options_list.map(&:strip).map(&:downcase)
          required = !(options == %w[yes no] || options == %w[no yes])
        end

        @computed_required[question.id] = required
      end
    end
  end

  def submit
    student = current_student

    unless student
      redirect_to student_dashboard_path, alert: "Student record not found for current user."
      return
    end

    answers = params[:answers] || {}

    allowed_question_ids = @survey.questions.pluck(:id)

    missing_required = []
    invalid_links = []

    @survey.questions.each do |question|
      submitted_value = answers[question.id.to_s]

      if question.is_required? && submitted_value.to_s.strip.blank?
        missing_required << question
      end

      if (question.question_type_evidence? || question.has_evidence_field?) && submitted_value.present?
        value_str = submitted_value.is_a?(String) ? submitted_value : submitted_value.to_s
        invalid_links << question unless value_str =~ StudentQuestion::DRIVE_URL_REGEX
      end
    end

    if missing_required.any?
      flash[:alert] = "Please answer all required questions (marked with *)."
      flash[:missing_required_ids] = missing_required.map(&:id)
      redirect_to survey_path(@survey) and return
    end

    if invalid_links.any?
      names = invalid_links.map { |q| "Question #{q.question_order}: #{q.question_text}" }
      redirect_to survey_path(@survey), alert: "One or more evidence links are invalid: #{names.join('; ')}"
      return
    end

    ActiveRecord::Base.transaction do
      allowed_question_ids.each do |question_id|
        submitted_value = answers[question_id.to_s]
        record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question_id)
        record.advisor_id ||= student.advisor_id

        if submitted_value.present?
          record.answer = submitted_value
          record.save!
        elsif record.persisted?
          record.destroy!
        end
      end
    end

    survey_response_id = SurveyResponse.build(student: student, survey: @survey).id
    redirect_to survey_response_path(survey_response_id), notice: "Survey submitted successfully!"
  end

  private

  def set_survey
    @survey = Survey.find(params[:id])
  end
end
