# frozen_string_literal: true

class StudentCompetenciesController < ApplicationController
  before_action :require_student!

  def show
    @payload = dashboard_payload

    respond_to do |format|
      format.html
      format.csv do
        send_data @payload[:csv],
                  filename: "my-competencies-#{Time.current.strftime('%Y%m%d-%H%M')}.csv",
                  type: "text/csv"
      end
    end
  end

  private

  def dashboard_payload
    StudentCompetencyDashboard.new(student: current_user.student_profile, params: params.permit(:semester)).call
  end

  def require_student!
    return if current_user&.role_student? && current_user.student_profile.present?

    redirect_to dashboard_path, alert: "Student competency dashboard is only available to students."
  end
end
