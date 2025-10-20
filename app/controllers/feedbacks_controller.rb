# CRUD endpoints for advisor feedback records associated with survey
# responses.
class FeedbacksController < ApplicationController
  before_action :set_feedback, only: %i[ show edit update destroy ]

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
    @feedback = Feedback.find(params[:id])
  end

  # Renders the new feedback form.
  #
  # @return [void]
  def new
    @survey = Survey.find(params[:survey_id])
    @student = Student.find(params[:student_id])
    @advisor = current_advisor_profile
    @feedback = Feedback.new

  # Load student answers for this survey. Use the student's primary key
  # (`student_id`) and the list of question ids belonging to the survey to
  # make this explicit and avoid join/namespace issues that can return an
  # empty relation in some cases.
  question_ids = @survey.questions.select(:id)
  @responses = StudentQuestion.where(student_id: @student.student_id, question_id: question_ids).includes(question: :category)
    # Build a SurveyResponse PORO so the view can render the same read-only
    # layout students see when viewing their responses.
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
    @survey = Survey.find(params[:survey_id])
    @student = Student.find(params[:student_id])
    @advisor = current_advisor_profile
    # Support two modes:
    # 1) legacy single-feedback form (feedback_params present)
    # 2) advisor provides per-category ratings via params[:ratings]
    if params[:ratings].present?
      # ratings is expected to be a hash like:
      # { "<category_id>" => { "id" => "<feedback_id optional>", "average_score" => "4", "comments" => "..." }, ... }
      ratings = params.require(:ratings).permit!.to_h

      Rails.logger.info "[FeedbacksController#create] received ratings keys=#{ratings.keys.inspect} payload_sample=#{ratings.values.first.inspect}"

      batch_errors = {}
      saved_feedbacks = []

      Feedback.transaction do
        ratings.each do |cat_id_str, data|
          cat_id = cat_id_str.to_i
          attrs = data.to_h

          # Skip empty inputs so we don't unintentionally erase existing feedback.
          if attrs["average_score"].blank? && attrs["comments"].blank?
            next
          end

          fb = if attrs["id"].present?
                 Feedback.find_by(id: attrs["id"])
               else
                 Feedback.find_or_initialize_by(student_id: @student.student_id, survey_id: @survey.id, category_id: cat_id, advisor_id: @advisor&.advisor_id)
               end

          fb.average_score = attrs["average_score"].presence
          fb.comments = attrs["comments"].presence
          fb.survey_id = @survey.id
          fb.student_id = @student.student_id
          fb.advisor_id = @advisor&.advisor_id
          fb.category_id = cat_id

          unless fb.save
            batch_errors[cat_id] = fb.errors.full_messages
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
        @feedback = Feedback.new
        load_feedback_new_context
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { errors: batch_errors }, status: :unprocessable_entity }
        end
        return
      end

      # all saved
      @feedback = saved_feedbacks.first
    elsif feedback_params[:category_id].present?
      # Per-category save when the form posts category_id, average_score, and comments
      @feedback = Feedback.new(
        survey: @survey,
        student: @student,
        advisor: @advisor,
        category_id: feedback_params[:category_id],
        average_score: feedback_params[:average_score],
        comments: feedback_params[:comments]
      )
    else
      # No supported input provided — render the new form with an explanatory error
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
        if params[:ratings].present?
          # For batch saves, return to student_records so the advisor returns to the list
          # after saving. The student_records page will show the new feedback under
          # 'View Feedback'.
          format.html { redirect_to student_records_path, notice: "Feedback saved." }
          format.json { render json: @feedback, status: :created, location: @feedback }
        else
          # per-category save — same behavior: go back to the student list
          format.html { redirect_to student_records_path, notice: "Category feedback saved." }
          format.json { render json: @feedback, status: :created, location: @feedback }
        end
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
    params.require(:feedback).permit(:advisor_id, :category_id, :surveyresponse_id, :comments, :average_score)
  end

  def load_feedback_new_context
    # Build PORO and related data the `new` view expects so re-rendering `new`
    # preserves student responses and existing feedback state.
    @survey_response = SurveyResponse.build(student: @student, survey: @survey)
    question_ids = @survey.questions.select(:id)
    @responses = StudentQuestion.where(student_id: @student.student_id, question_id: question_ids).includes(question: :category)
    @existing_feedbacks = Feedback.where(student_id: @student.student_id, survey_id: @survey.id).includes(:category, :advisor)
    @existing_feedbacks_by_category = @existing_feedbacks.index_by(&:category_id)
  end

  def set_survey_and_student
    @survey = Survey.find(params[:survey_id])
    @student = Student.find(params[:student_id])
  end
end
