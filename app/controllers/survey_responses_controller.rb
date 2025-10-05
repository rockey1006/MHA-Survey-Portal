class SurveyResponsesController < ApplicationController
  before_action :set_survey_response, only: %i[ show edit update destroy reopen ]
  before_action :authorize_student_view!, only: %i[ show edit update destroy ]

  # GET /survey_responses or /survey_responses.json
  def index
    @survey_responses = SurveyResponse.all
  end

  # GET /survey_responses/1 or /survey_responses/1.json
  def show
    @question_responses = @survey_response.question_responses.includes(:question)

    respond_to do |format|
      format.html
      format.pdf do
        html = render_to_string(
          template: "survey_responses/show",
          layout: "pdf",
          encoding: "UTF-8",
          locals: { :@survey_response => @survey_response, :@question_responses => @question_responses }
        )
        render pdf: "survey_response_#{@survey_response.id}",
               html: html,
               encoding: "UTF-8"
      end
    end
  end

  # GET /survey_responses/new
  def new
    @survey_response = SurveyResponse.new
  end

  # GET /survey_responses/1/edit
  def edit
    # Only non-student users (advisors/admins) may edit
    if current_student && @survey_response.student_id == current_student.id
      redirect_to @survey_response, alert: "Students are not allowed to edit survey responses."
    end
  end

  # POST /survey_responses or /survey_responses.json
  def create
    @survey_response = SurveyResponse.new(survey_response_params)

    respond_to do |format|
      if @survey_response.save
        format.html { redirect_to @survey_response, notice: "Survey response was successfully created." }
        format.json { render :show, status: :created, location: @survey_response }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @survey_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /survey_responses/1 or /survey_responses/1.json
  def update
    # Prevent students from updating
    if current_student && @survey_response.student_id == current_student.id
      redirect_to @survey_response, alert: "Students are not allowed to update survey responses." and return
    end
    respond_to do |format|
      if @survey_response.update(survey_response_params)
        format.html { redirect_to @survey_response, notice: "Survey response was successfully updated." }
        format.json { render :show, status: :ok, location: @survey_response }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @survey_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /survey_responses/1 or /survey_responses/1.json
  def destroy
    # Prevent students from destroying
    if current_student && @survey_response.student_id == current_student.id
      redirect_to survey_responses_path, alert: "Students are not allowed to destroy survey responses." and return
    end
    @survey_response.destroy!

    respond_to do |format|
      format.html { redirect_to survey_responses_path, notice: "Survey response was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # PATCH /survey_responses/:id/reopen
  def reopen
    # Only allow reopening if current_student owns it
    if current_student && @survey_response.student_id == current_student.id
      @survey_response.update!(status: SurveyResponse.statuses[:not_started])
      redirect_to student_dashboard_path, notice: "Survey has been moved back to To-do."
    else
      redirect_to survey_responses_path, alert: "Not authorized to reopen this survey."
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_survey_response
      @survey_response = SurveyResponse.find(params[:id])
    end

    def authorize_student_view!
      # Students may only view their own survey responses. Advisors and admins can view any.
      return unless current_student
      if @survey_response && @survey_response.student_id != current_student.id
        redirect_to student_dashboard_path, alert: "You are not authorized to view that survey response."
      end
    end

    # Only allow a list of trusted parameters through.
    def survey_response_params
      params.require(:survey_response).permit(:student_id, :advisor_id, :survey_id, :completion_date, :approval_date, :status)
    end
end
