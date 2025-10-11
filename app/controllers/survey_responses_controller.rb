class SurveyResponsesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[ download ]
  before_action :set_survey_response, only: %i[ show edit update destroy reopen download ]
  before_action :authorize_student_view!, only: %i[ show edit update destroy ]

  # GET /survey_responses/:id/download?token=...
  def download
    token = params[:token]
    # Allow access if token valid or current_user is authorized
    if token.present?
      found = SurveyResponse.find_by_signed_download_token(token)
      unless found && found.id == @survey_response.id
        head :unauthorized and return
      end
    else
      # No token provided: require authentication and authorization as usual
      unless current_user && (current_user.admin? || current_user.advisor? || @survey_response.student_id == current_user.student_profile&.id)
        head :unauthorized and return
      end
    end

    @question_responses = @survey_response.question_responses.includes(:question)
    begin
  # Render the actual HTML partial into a string, then render that
  # string into the PDF layout using `inline:` so the layout's
  # <%= yield %> receives the full body content reliably.
  inner = render_to_string(partial: "survey_responses/survey_response", formats: [ :html ], locals: { survey_response: @survey_response })
  html = render_to_string(inline: inner, layout: "pdf", formats: [ :html ], encoding: "UTF-8")
      send_data WickedPdf.new.pdf_from_string(html), filename: "survey_response_#{@survey_response.surveyresponse_id || @survey_response.id}.pdf", disposition: "attachment", type: "application/pdf"
    rescue => e
      logger.error "Download PDF failed for SurveyResponse #{ @survey_response&.surveyresponse_id }: #{e.class} - #{e.message}\n#{e.backtrace.join("\n") }"
      head :internal_server_error
    end
  end

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
        begin
              inner = render_to_string(partial: "survey_responses/survey_response", formats: [ :html ], locals: { survey_response: @survey_response })
              html = render_to_string(inline: inner, layout: "pdf", formats: [ :html ], encoding: "UTF-8")
         render pdf: "survey_response_#{@survey_response.id}",
           html: html,
           encoding: "UTF-8",
           disposition: "attachment",
           filename: "survey_response_#{@survey_response.surveyresponse_id || @survey_response.id}.pdf"
        rescue => e
          # Log the full error for debugging and fall back gracefully to HTML view
          logger.error "PDF generation failed for SurveyResponse #{ @survey_response&.surveyresponse_id }: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
          redirect_to @survey_response, alert: "PDF generation failed on the server. The response will be shown in the browser instead."
        end
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
