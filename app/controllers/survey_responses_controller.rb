# Presents individual survey responses for viewing, printing, or exporting,
# enforcing authorization rules for admins, advisors, and students.
class SurveyResponsesController < ApplicationController
  before_action :set_survey_response
  before_action :authorize_view!

  # Shows a survey response within the standard layout.
  #
  # @return [void]
  def show
    @question_responses = preload_question_responses
  end

  # Renders the print-friendly layout for a survey response.
  #
  # @return [void]
  def print
    @question_responses = preload_question_responses

    respond_to do |format|
      format.html { render :print, layout: "print" }
    end
  end

  # Streams a PDF version of the survey response when WickedPdf is available.
  # Falls back with an error when server-side rendering is disabled.
  #
  # @return [void]
  def download
    @question_responses = preload_question_responses

    unless defined?(WickedPdf)
      logger.warn "Server-side PDF generation requested but WickedPdf is not available"
      render plain: "Server-side PDF generation unavailable. Please use the 'Download as PDF' button which uses your browser's Print/Save-as-PDF feature.", status: :service_unavailable and return
    end

    pdf_data = generate_pdf

    unless pdf_data&.start_with?("%PDF")
      logger.error "PDF generation returned non-PDF payload for SurveyResponse=#{@survey_response.id}: first bytes=#{pdf_data&.byteslice(0, 128).inspect}"
      head :internal_server_error and return
    end

    begin
      filename = "survey_response_#{@survey_response.id}.pdf"
      send_data pdf_data, filename: filename, disposition: "attachment", type: "application/pdf"
    rescue => e
      logger.error "Download PDF failed for SurveyResponse #{@survey_response.id}: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
      head :internal_server_error
    end
  end

  private

  # Finds the survey response by signed token or ID parameter.
  #
  # @return [void]
  def set_survey_response
    token = params[:token].presence

    @survey_response = if token
      SurveyResponse.find_by_signed_download_token(token)
    elsif params[:id].present?
      SurveyResponse.find_from_param(params[:id])
    end

    return if @survey_response

    logger.warn "SurveyResponse lookup failed for id=#{params[:id]} token_present=#{token.present?}"
    head :not_found
  end

  # Ensures the current user is permitted to view the response.
  #
  # @return [void]
  def authorize_view!
    return if params[:token].present? # signed token grants access without session

    current = current_user
    if current&.admin? || current&.advisor?
      return
    end

    student_profile = current_student
    if student_profile && student_profile.student_id == @survey_response.student_id
      return
    end

    logger.warn "Authorization failed for SurveyResponse #{@survey_response.id} user=#{current&.id}"
    head :unauthorized
  end

  # Preloads related question responses for rendering.
  #
  # @return [ActiveRecord::Associations::CollectionProxy<QuestionResponse>]
  def preload_question_responses
    @survey_response.question_responses
  end

  # Generates a PDF payload from the survey response using WickedPdf.
  #
  # @return [String, nil]
  def generate_pdf
    html = render_to_string(
      template: "survey_responses/show",
      layout: "pdf",
      formats: [ :html ],
      encoding: "UTF-8",
      locals: { survey_response: @survey_response }
    )

    WickedPdf.new.pdf_from_string(html)
  rescue => e
    logger.error "PDF generation raised #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
    nil
  end
end
