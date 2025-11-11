# frozen_string_literal: true

class ReportsController < ApplicationController
  before_action :ensure_reports_access!

  def show
  end

  def export_pdf
  payload = aggregator.export_payload
  section = normalize_export_section(reports_params[:section])

    unless defined?(WickedPdf)
      render plain: "PDF export unavailable. WickedPdf is not configured.", status: :service_unavailable
      return
    end

    html = render_to_string(
      template: "reports/export",
      layout: "report_pdf",
  locals: { payload: payload, export_section: section }
    )

    pdf = WickedPdf.new.pdf_from_string(html, page_size: "Letter", orientation: "Landscape")

    send_data pdf,
              filename: "health-reports-#{Time.current.strftime('%Y%m%d-%H%M')}.pdf",
              disposition: "attachment",
              type: "application/pdf"
  end

  def export_excel
  payload = aggregator.export_payload
  section = normalize_export_section(reports_params[:section])
    package = Reports::ExcelExporter.new(payload, section: section).generate

    send_data package.to_stream.read,
              filename: "health-reports-#{Time.current.strftime('%Y%m%d-%H%M')}.xlsx",
              disposition: "attachment",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  private

  def ensure_reports_access!
    return if current_user.role_admin? || current_user.role_advisor?

    redirect_to dashboard_path, alert: "Reports are only available to administrators and advisors."
  end

  def aggregator
    @aggregator ||= Reports::DataAggregator.new(user: current_user, params: reports_filter_params)
  end

  def reports_params
    params.permit(:track, :semester, :survey_id, :category_id, :student_id, :advisor_id, :section)
  end

  def reports_filter_params
    reports_params.except(:section)
  end

  def normalize_export_section(value)
    normalized = value.to_s.strip
    return nil if normalized.blank?
    return nil if %w[dashboard all full default].include?(normalized)

    normalized
  end
end
