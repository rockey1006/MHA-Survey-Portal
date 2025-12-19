# CRUD endpoints for advisor feedback records associated with survey
# responses.
class FeedbacksController < ApplicationController
  before_action :set_feedback, only: %i[ show edit update destroy ]
  before_action :set_survey_and_student, only: %i[new create]

  # Lists all feedback entries.
  #
  # @return [void]
  def index
    @feedbacks = Feedback.all
  end

  # Displays a single feedback entry.
  #
  # @return [void]
  def show
  end

  # Renders the new feedback form.
  #
  # @return [void]
  def new
    load_feedback_new_context
  end

  # Renders the edit form for existing feedback.
  #
  # @return [void]
  def edit; end

  # Creates a feedback record from submitted attributes.
  #
  # @return [void]
  def create
    Rails.logger.debug "[FeedbacksController#create] params_keys=#{params.keys.inspect} ratings_present=#{params[:ratings].present?} feedback_present=#{params[:feedback].present?}"
    @advisor = current_advisor_profile
    # Support two modes:
    # 1) batch per-category ratings via params[:ratings]
    # 2) per-category single feedback via nested feedback params
    if params[:ratings].present?
      raw_ratings = params.require(:ratings)
      ratings = raw_ratings.to_unsafe_h.each_with_object({}) do |(cat_id, values), memo|
        allowed = if values.respond_to?(:permit)
                    values.permit(:id, :average_score, :comments).to_h
        else
                    values.to_h.slice("id", "average_score", "comments")
        end
        memo[cat_id] = allowed
      end

      batch_errors = {}
      saved_feedbacks = []

      Feedback.transaction do
        ratings.each do |qid_str, data|
          Rails.logger.debug "[FeedbacksController#create] processing question=#{qid_str} data=#{data.inspect}"
          qid = qid_str.to_i
          attrs = data.to_h

          # Skip empty inputs
          next if attrs["average_score"].blank? && attrs["comments"].blank?

          question = Question.find_by(id: qid)

          fb = if attrs["id"].present?
            Feedback.find_by(id: attrs["id"], student_id: @student.student_id, survey_id: @survey.id, advisor_id: @advisor&.advisor_id)
          else
            Feedback.new(student_id: @student.student_id,
              survey_id: @survey.id,
              question_id: qid,
              category_id: question&.category_id,
              advisor_id: @advisor&.advisor_id)
          end

          Rails.logger.debug "[FeedbacksController#create] found fb=#{fb.inspect} attrs=#{attrs.inspect}"

          unless fb
            batch_errors[qid] = [ "Feedback record not found" ]
            next
          end

          fb.average_score = attrs["average_score"].presence
          fb.comments = attrs["comments"].presence
          fb.survey_id = @survey.id
          fb.student_id = @student.student_id
          fb.advisor_id = @advisor&.advisor_id
          fb.question_id = qid

          unless fb.save
            batch_errors[qid] = fb.errors.full_messages
          else
            saved_feedbacks << fb
          end
        end

        if batch_errors.any?
          raise ActiveRecord::Rollback
        end
      end

      if batch_errors.any?
        @batch_errors = batch_errors
        Rails.logger.error "[FeedbacksController#create] batch_errors=#{batch_errors.inspect}"
        @feedback = Feedback.new
        load_feedback_new_context
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { errors: batch_errors }, status: :unprocessable_entity }
        end
        return
      end

      if saved_feedbacks.empty?
        Rails.logger.error "[FeedbacksController#create] saved_feedbacks empty; ratings=#{ratings.inspect}"
        @feedback = Feedback.new
        @feedback.errors.add(:base, "No ratings provided")
        load_feedback_new_context
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { error: "No ratings provided" }, status: :unprocessable_entity }
        end
        return
      end

      @feedback = saved_feedbacks.first

      respond_to do |format|
        format.html { redirect_to student_records_path, notice: "Feedback saved." }
        format.json { render json: saved_feedbacks, status: :created }
      end
      return
    elsif params[:feedback].present? && params.dig(:feedback, :question_id).present?
      # per-question single feedback
      set_survey_and_student unless @survey && @student
      @advisor = current_advisor_profile
      @feedback = Feedback.new(
        survey_id: @survey.id,
        student_id: @student.student_id,
        advisor_id: @advisor&.advisor_id,
        question_id: feedback_params[:question_id],
        category_id: Question.find_by(id: feedback_params[:question_id])&.category_id,
        average_score: feedback_params[:average_score],
        comments: feedback_params[:comments]
      )
    else
      @feedback = Feedback.new
      @feedback.errors.add(:base, "No category or ratings provided")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: "No category or ratings provided" }, status: :unprocessable_entity }
      end
      return
    end

    respond_to do |format|
      if @feedback.save
        format.html { redirect_to student_records_path, notice: "Category feedback saved." }
        format.json { render json: @feedback, status: :created, location: @feedback }
      else
        load_feedback_new_context
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @feedback.errors, status: :unprocessable_entity }
      end
    end
  end

  # Updates an existing feedback entry.
  #
  # @return [void]
  def update
    respond_to do |format|
      if @feedback.update(feedback_params)
        # If we have survey_id and student_id context, redirect back to the advisor feedback page
        if feedback_params[:survey_id].present? && feedback_params[:student_id].present?
          format.html { redirect_to new_feedback_path(survey_id: feedback_params[:survey_id], student_id: feedback_params[:student_id]), notice: "Feedback was successfully updated.", status: :see_other }
        else
          format.html { redirect_to @feedback, notice: "Feedback was successfully updated.", status: :see_other }
        end
        format.json { render :show, status: :ok, location: @feedback }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @feedback.errors, status: :unprocessable_entity }
      end
    end
  end

  # Deletes feedback and redirects back to the index.
  #
  # @return [void]
  def destroy
    @feedback.destroy!

    respond_to do |format|
      format.html { redirect_to feedbacks_path, notice: "Feedback was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
  # Finds the feedback referenced in the request.
  #
  # @return [void]
  def set_feedback
    @feedback = Feedback.find(params[:id])
  end

  # Strong parameters for feedback creation/update.
  #
  # @return [ActionController::Parameters]
  def feedback_params
    params.require(:feedback).permit(:advisor_id, :category_id, :survey_id, :student_id, :comments, :average_score)
  end

  def load_feedback_new_context
    # Build PORO and related data the `new` view expects so re-rendering `new`
    # preserves student responses and existing feedback state.
    @survey_response = SurveyResponse.build(student: @student, survey: @survey)
    question_ids = @survey.questions.select(:id)
    @responses = StudentQuestion.where(student_id: @student.student_id, question_id: question_ids).includes(question: :category)
    @existing_feedbacks = Feedback.where(student_id: @student.student_id, survey_id: @survey.id).includes(:category, :advisor, :question)

    pick_latest = lambda do |items|
      items.compact.max_by { |fb| fb.updated_at || fb.created_at || Time.at(0) }
    end

    @existing_feedbacks_by_category = @existing_feedbacks
      .select { |fb| fb.category_id.present? }
      .group_by(&:category_id)
      .transform_values { |items| pick_latest.call(items) }

    @existing_feedbacks_by_question = @existing_feedbacks
      .select { |fb| fb.question_id.present? }
      .group_by(&:question_id)
      .transform_values { |items| pick_latest.call(items) }
  end

  def set_survey_and_student
    survey_id = params[:survey_id] || params.dig(:feedback, :survey_id)
    student_id = params[:student_id] || params.dig(:feedback, :student_id)

    @survey = Survey.find(survey_id)
    @student = Student.find(student_id)
  end
end
