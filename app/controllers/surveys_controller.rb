class SurveysController < ApplicationController
  before_action :set_survey, only: %i[ show edit update destroy submit ]

  # GET /surveys or /surveys.json
  def index
    @surveys = Survey.all
  end

  # GET /surveys/1 or /surveys/1.json
  def show
    @survey_response = nil
    @existing_answers = {}

    if current_student
      @survey_response = SurveyResponse.find_by(student_id: current_student.id, survey_id: @survey.id)
      @existing_answers = @survey_response&.question_responses&.index_by(&:question_id) || {}
    end
  end

  # GET /surveys/new
  def new
    @survey = Survey.new
  end

  # GET /surveys/1/edit
  def edit
  end

  # POST /surveys or /surveys.json
  def create
    @survey = Survey.new(survey_params)

    respond_to do |format|
      if @survey.save
        format.html { redirect_to @survey, notice: "Survey was successfully created." }
        format.json { render :show, status: :created, location: @survey }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @survey.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /surveys/1 or /surveys/1.json
  def update
    respond_to do |format|
      if @survey.update(survey_params)
        format.html { redirect_to @survey, notice: "Survey was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @survey }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @survey.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /surveys/1 or /surveys/1.json
  def destroy
    @survey.destroy!

    respond_to do |format|
      format.html { redirect_to surveys_path, notice: "Survey was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # POST /surveys/:id/submit
  def submit
    student = current_student
    unless student
      redirect_to student_dashboard_path, alert: "Student record not found for current user."
      return
    end

    survey_response = SurveyResponse.find_or_initialize_by(student_id: student.id, survey_id: @survey.id)
    survey_response.status = SurveyResponse.statuses[:submitted]
    survey_response.advisor_id ||= student.advisor_id
    survey_response.completion_date ||= Date.current

    ActiveRecord::Base.transaction do
      survey_response.save!

      answers = params.fetch(:answers, {})
      answers.each do |question_id_str, raw_answer|
        next unless question_id_str.to_s =~ /^\d+$/
        question = Question.find_by(question_id: question_id_str.to_i)
        next unless question

        response_value = normalize_answer(raw_answer)
        question_response = QuestionResponse.find_or_initialize_by(
          surveyresponse_id: survey_response.id,
          question_id: question.question_id
        )
        question_response.answer = response_value
        question_response.save!
      end
    end

    respond_to do |format|
      format.html { redirect_to survey_response_path(survey_response), notice: "Survey submitted successfully!" }
      format.json { render json: { survey_response_id: survey_response.id }, status: :ok }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.html do
        redirect_to survey_path(@survey), alert: "Unable to submit survey: #{e.record.errors.full_messages.to_sentence}"
      end
      format.json { render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity }
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_survey
      @survey = Survey.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def survey_params
      params.require(:survey).permit(:title, :semester)
    end

    def normalize_answer(raw_answer)
      case raw_answer
      when ActionController::Parameters
        normalize_answer(raw_answer.permit!.to_h)
      when Hash
        raw_answer.transform_values { |value| normalize_answer(value) }
      when Array
        raw_answer.map { |value| normalize_answer(value) }.reject { |value| value.respond_to?(:blank?) ? value.blank? : value.nil? }
      else
        raw_answer
      end
    end
end
