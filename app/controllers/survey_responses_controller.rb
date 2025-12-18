# Presents individual survey responses for viewing, printing, or exporting,
# enforcing authorization rules for admins, advisors, and students.
class SurveyResponsesController < ApplicationController
  before_action :set_survey_response
  before_action :authorize_view!, only: %i[show download]
  before_action :authorize_composite!, only: :composite_report

  # Shows a survey response within the standard layout.
  #
  # @return [void]
  def show
    @question_responses = preload_question_responses
  end

  # Streams a PDF version of the survey response that matches the composite report payload.
  #
  # @return [void]
  def download
    unavailable_message = "Server-side PDF generation unavailable. Please use the 'Download as PDF' button which uses your browser's Print/Save-as-PDF feature."
    unless defined?(WickedPdf)
      logger.warn "Server-side PDF generation requested but WickedPdf is not available"
      render plain: unavailable_message, status: :service_unavailable and return
    end

    result = nil

    begin
      generator = CompositeReportGenerator.new(survey_response: @survey_response, cache: false)
      result = generator.render
      filename = survey_pdf_filename(@survey_response)
      stream_pdf_result(result, filename, unavailable_message: unavailable_message)
    rescue CompositeReportGenerator::MissingDependency
      render plain: "Server-side PDF generation unavailable. WickedPdf not configured.", status: :service_unavailable
    rescue CompositeReportGenerator::GenerationError => e
      logger.error "Download PDF failed for SurveyResponse #{@survey_response.id}: #{e.message}"
      head :internal_server_error
    rescue => e
      message = <<~MSG
        Download PDF failed for SurveyResponse #{@survey_response.id}: #{e.class} - #{e.message}
        #{e.backtrace&.join("\n")}
      MSG
      logger.error(message.strip)
      head :internal_server_error
    ensure
      result&.cleanup!
    end
  end

  # Streams a composite PDF aggregating student responses and advisor feedback.
  #
  # @return [void]
  def composite_report
    unavailable_message = "Composite PDF generation unavailable. Please try again later."
    unless defined?(WickedPdf)
      logger.warn "Composite PDF generation requested but WickedPdf is not available"
      render plain: unavailable_message, status: :service_unavailable and return
    end

    result = nil

    begin
      generator = CompositeReportGenerator.new(survey_response: @survey_response)
      result = generator.render
      filename = "composite_assessment_#{@survey_response.id}.pdf"
      stream_pdf_result(result, filename, unavailable_message: unavailable_message)
    rescue CompositeReportGenerator::MissingDependency
      render plain: "Composite PDF generation unavailable. WickedPdf not configured.", status: :service_unavailable
    rescue CompositeReportGenerator::GenerationError => e
      logger.error "Composite report generation failed for SurveyResponse #{@survey_response.id}: #{e.message}"
      head :internal_server_error
    rescue => e
      message = <<~MSG
        Download composite PDF failed for SurveyResponse #{@survey_response.id}: #{e.class} - #{e.message}
        #{e.backtrace&.join("\n")}
      MSG
      logger.error(message.strip)
      head :internal_server_error
    ensure
      result&.cleanup!
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
    if current&.role_admin?
      return
    end

    if current&.role_advisor?
      advisor_profile = current_advisor_profile
      assigned_advisor_id = @survey_response&.advisor_id

      if advisor_profile && assigned_advisor_id.present? && advisor_profile.advisor_id == assigned_advisor_id
        return
      end
    end

    student_profile = current_student
    if student_profile && student_profile.student_id == @survey_response.student_id
      return
    end

    logger.warn "Authorization failed for SurveyResponse #{@survey_response.id} user=#{current&.id}"
    head :unauthorized
  end

  # Ensures only admins or the student's assigned advisor can generate composite reports.
  #
  # @return [void]
  def authorize_composite!
    unless @survey_response
      head :not_found and return
    end

    if params[:token].present?
      logger.warn "Composite report access via token rejected for SurveyResponse #{@survey_response&.id}"
      head :unauthorized and return
    end

    current = current_user
    unless current
      logger.warn "Composite report access without authenticated user for SurveyResponse #{@survey_response&.id}"
      head :unauthorized and return
    end

    if current.role_admin?
      return
    end

    advisor_profile = current_advisor_profile
    assigned_advisor_id = @survey_response.advisor_id

    if advisor_profile && assigned_advisor_id.present? && advisor_profile.advisor_id == assigned_advisor_id
      return
    end

    logger.warn "Composite report authorization failed for SurveyResponse #{@survey_response&.id} user=#{current.id}"
    head :unauthorized
  end

  # Preloads related question responses for rendering.
  #
  # @return [ActiveRecord::Associations::CollectionProxy<QuestionResponse>]
  def preload_question_responses
    @survey_response.question_responses
  end

  # Sends the generated PDF with validation to guard against corrupt files.
  #
  # @param result [CompositeReportGenerator::Result]
  # @param filename [String]
  # @return [void]
  def stream_pdf_result(result, filename, unavailable_message: nil)
    path = result&.path

    unless path && File.exist?(path)
      logger.error "Composite PDF generation returned an invalid file for SurveyResponse=#{@survey_response.id}"
      return render_unavailable(unavailable_message)
    end

    pdf_data = read_pdf_bytes(path)
    return render_unavailable(unavailable_message) unless pdf_data

    unless pdf_data.start_with?("%PDF")
      logger.error "Composite PDF generation returned non-PDF payload for SurveyResponse=#{@survey_response.id}: first bytes=#{pdf_data.byteslice(0, 4).inspect}"
      return render_unavailable(unavailable_message)
    end

    send_data pdf_data, filename: filename, disposition: "attachment", type: "application/pdf"
  end

  def read_pdf_bytes(path)
    File.binread(path)
  rescue Errno::ENOENT => e
    logger.error "Composite PDF generation file missing for SurveyResponse=#{@survey_response.id}: #{e.message}"
    nil
  end

  def render_unavailable(message)
    if message.present?
      render plain: message, status: :service_unavailable
    else
      head :internal_server_error
    end
  end

  def survey_pdf_filename(survey_response)
    student_part = safe_filename_part(
      survey_response&.student&.user&.display_name,
      fallback: "student_#{survey_response&.student_id}"
    )

    survey_part = safe_filename_part(
      survey_response&.survey&.title,
      fallback: "survey_#{survey_response&.survey_id}"
    )

    "#{student_part}_#{survey_part}.pdf"
  end

  def safe_filename_part(value, fallback: "file")
    raw = value.to_s.strip
    raw = fallback.to_s.strip if raw.blank?

    sanitized = raw.parameterize(separator: "_")
    sanitized = fallback.to_s.parameterize(separator: "_") if sanitized.blank?
    sanitized
  end
end
