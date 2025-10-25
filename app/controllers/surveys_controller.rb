# Handles student-facing survey listing, completion, and submission flows.
class SurveysController < ApplicationController
  protect_from_forgery except: :save_progress
  before_action :set_survey, only: %i[show submit save_progress]

  # Lists active surveys ordered by display priority.
  #
  # @return [void]
  def index
    @surveys = Survey.active.ordered
  end

  # Presents the survey form, pre-populating answers and required flags.
  #
  # @return [void]
  def show
  Rails.logger.info "[EVIDENCE DEBUG] show: session[:invalid_evidence]=#{session[:invalid_evidence].inspect}" # debug session evidence
    @category_groups = @survey.categories.includes(:questions).order(:id)
    @existing_answers = {}
    @computed_required = {}
    student = current_student

    Rails.logger.info "[SHOW DEBUG] Student ID: #{student&.student_id}"
    Rails.logger.info "[SHOW DEBUG] Survey ID: #{@survey.id}"

    if student
      responses = StudentQuestion
                    .where(student_id: student.student_id, question_id: @survey.questions.select(:id))
                    .includes(:question)

      Rails.logger.info "[SHOW DEBUG] Found #{responses.count} saved responses"

      responses.each do |response|
        # Use string key to match view's expectation
        @existing_answers[response.question_id.to_s] = response.answer
        Rails.logger.info "[SHOW DEBUG] Question #{response.question_id}: #{response.answer.inspect}"
      end
    end

    Rails.logger.info "[SHOW DEBUG] Total existing answers: #{@existing_answers.size}"
    Rails.logger.info "[SHOW DEBUG] Answer keys: #{@existing_answers.keys.inspect}"

    @category_groups.each do |category|
      category.questions.each do |question|
        required = question.is_required?

        if !required && question.question_type_multiple_choice?
          options = question.answer_options_list.map(&:strip).map(&:downcase)
          # Exception: flexibility scale questions (1-5) should remain optional
          is_flexibility_scale = (options == %w[1 2 3 4 5]) &&
                                 question.question_text.to_s.downcase.include?("flexible")
          required = !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
        end

        @computed_required[question.id] = required
      end
    end


    @invalid_evidence ||= nil
  end

  # Processes survey submissions, validating required answers and evidence
  # links before persisting student responses.
  #
  # @return [void]
  def submit
  Rails.logger.info "[EVIDENCE DEBUG] SurveysController#submit called"
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

      # Apply the same required logic as in show action
      required = question.is_required?
      if !required && question.question_type_multiple_choice?
        options = question.answer_options_list.map(&:strip).map(&:downcase)
        is_flexibility_scale = (options == %w[1 2 3 4 5]) &&
                               question.question_text.to_s.downcase.include?("flexible")
        required = !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
      end

      if required && submitted_value.to_s.strip.blank?
        missing_required << question
      end

      # Debug evidence question type and value
      if submitted_value.present?
        Rails.logger.info "[EVIDENCE DEBUG] QID: #{question.id}, TYPE: #{question.question_type.inspect}, VALUE: #{submitted_value.inspect}"
      end
      # Only validate evidence questions for Google Drive link
      if question.question_type == "evidence" && submitted_value.present?
        value_str = submitted_value.is_a?(String) ? submitted_value : submitted_value.to_s
        unless value_str =~ StudentQuestion::DRIVE_URL_REGEX
          Rails.logger.info "[EVIDENCE DEBUG] INVALID evidence for QID: #{question.id} VALUE: #{value_str.inspect}"
          invalid_links << question
        end
      end
    end

    if missing_required.any? || invalid_links.any?
      @category_groups = @survey.categories.includes(:questions).order(:id)
      @existing_answers = answers
      @computed_required = {}
      @invalid_evidence = invalid_links.map(&:id)
      @category_groups.each do |category|
        category.questions.each do |question|
          required = question.is_required?
          if !required && question.question_type_multiple_choice?
            options = question.answer_options_list.map(&:strip).map(&:downcase)
            is_flexibility_scale = (options == %w[1 2 3 4 5]) &&
                                   question.question_text.to_s.downcase.include?("flexible")
            required = !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
          end
          @computed_required[question.id] = required
        end
      end
      render :show, status: :unprocessable_entity and return
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

  # Saves the current survey progress without validating required fields.
  # Allows students to save their work and continue later.
  #
  # @return [void]
  def save_progress
    student = current_student

    unless student
      redirect_to student_dashboard_path, alert: "Student record not found for current user."
      return
    end

    answers = params[:answers] || {}
    allowed_question_ids = @survey.questions.pluck(:id)

    Rails.logger.info "[SAVE_PROGRESS DEBUG] Student ID: #{student.student_id}"
    Rails.logger.info "[SAVE_PROGRESS DEBUG] Answers received: #{answers.inspect}"
    Rails.logger.info "[SAVE_PROGRESS DEBUG] Allowed question IDs: #{allowed_question_ids.inspect}"

    saved_count = 0
    ActiveRecord::Base.transaction do
      allowed_question_ids.each do |question_id|
        submitted_value = answers[question_id.to_s]
        Rails.logger.info "[SAVE_PROGRESS DEBUG] Question #{question_id}: value=#{submitted_value.inspect}"

        record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question_id)
        record.advisor_id ||= student.advisor_id

        if submitted_value.present?
          record.answer = submitted_value
          record.save!
          saved_count += 1
          Rails.logger.info "[SAVE_PROGRESS DEBUG] Saved question #{question_id} with value: #{submitted_value}"
        elsif record.persisted?
          record.destroy!
          Rails.logger.info "[SAVE_PROGRESS DEBUG] Destroyed empty answer for question #{question_id}"
        end
      end
    end

    Rails.logger.info "[SAVE_PROGRESS DEBUG] Total saved: #{saved_count} answers"
    redirect_to survey_path(@survey), notice: "Progress saved! You can continue later."
  end

  private

  # Finds the survey requested by the route.
  #
  # @return [void]
  def set_survey
    @survey = Survey.find(params[:id])
  end
end
