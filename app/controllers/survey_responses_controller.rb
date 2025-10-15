class SurveyResponsesController < ApplicationController
  before_action :set_survey_response
  before_action :authorize_view!

  def show
    @question_responses = preload_question_responses
  end

  def print
    @question_responses = preload_question_responses

    respond_to do |format|
      format.html { render :print, layout: "print" }
    end
  end

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

  def preload_question_responses
    @survey_response.question_responses
  end

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
