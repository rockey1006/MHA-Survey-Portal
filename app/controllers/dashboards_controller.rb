class DashboardsController < ApplicationController
  before_action :authenticate_admin!

  def show
    # Default dashboard - redirect based on role
    case current_admin.role
    when "student"
      redirect_to student_dashboard_path
    when "advisor"
      redirect_to advisor_dashboard_path
    when "admin"
      redirect_to admin_dashboard_path
    else
      # Fallback - if no role is set, redirect to student for now
      redirect_to student_dashboard_path
    end
  end

  def student
    # Student dashboard
    # Try to map the signed-in admin to a Student record by email
    @student = nil
    if defined?(current_admin) && current_admin.present?
      @student = Student.find_by(email: current_admin.email)

    @pending_surveys = [
      { id: 1, title: "Health & Wellness Survey" },
      { id: 3, title: "Career Goals Survey" }
    ]
    @completed_surveys = []
    end

    if @student
      # Ensure there are at least 3 surveys in the system and each has 5 questions
      (1..3).each do |i|
        # Attempt to find or create by the external survey_id. In rare cases a
        # create can fail with a unique constraint on the primary key (sequence
        # out of sync or race). Rescue and fetch the existing record instead of
        # letting the request raise 404.
        begin
          survey = Survey.find_or_create_by(survey_id: i) do |s|
            s.assigned_date = Date.today
          end
        rescue ActiveRecord::RecordNotUnique => e
          Rails.logger.warn "Survey create conflict for survey_id=#{i}: #{e.message}"
          survey = Survey.find_by(survey_id: i)
          # If we still can't find the survey something else is wrong — re-raise
          raise unless survey
        end

        # ensure 5 questions for this survey via competencies -> questions; we'll create a single competency to hold them
        if survey.competencies.empty?
          comp = survey.competencies.create!(name: "Default competency #{survey.id}", description: "Auto-generated")
          # create five questions: select, checkbox, radio, text, text
          comp.questions.create!(question_order: 1, question_type: "select", question: "Choose your primary focus", answer_options: "Leadership,Analytics,Finance")
          comp.questions.create!(question_order: 2, question_type: "checkbox", question: "Which skills improved", answer_options: "Leadership,Analytics,Finance")
          comp.questions.create!(question_order: 3, question_type: "radio", question: "Do you feel confident?", answer_options: "Yes,No")
          comp.questions.create!(question_order: 4, question_type: "text", question: "Please describe one achievement", answer_options: nil)
          comp.questions.create!(question_order: 5, question_type: "text", question: "Any additional feedback", answer_options: nil)
        end

        # create a SurveyResponse for this student if missing
        sr = SurveyResponse.find_or_initialize_by(student_id: @student.id, survey_id: survey.id)
        if sr.new_record?
          sr.status = SurveyResponse.statuses[:not_started]
          sr.advisor_id = @student.advisor_id
          sr.save!
        end
      end

      # pending: not submitted
      @pending_survey_responses = SurveyResponse.pending_for_student(@student.id)
      @pending_surveys = Survey.where(id: @pending_survey_responses.pluck(:survey_id))

      # completed: submitted
      @completed_survey_responses = SurveyResponse.completed_for_student(@student.id)
      @completed_surveys = Survey.where(id: @completed_survey_responses.pluck(:survey_id))
    else
      @pending_surveys = []
      @completed_surveys = []
    end
  end

  def advisor
    # Advisor dashboard (also used by admins with additional features)
  end

  def admin
    # Admin dashboard - loads data for admin view
    @total_students = Admin.where(role: "student").count
    @total_advisors = Admin.where(role: "advisor").count
    @total_surveys = 0 # Placeholder for when surveys are implemented
    @total_notifications = 0 # Placeholder for notifications
    @total_users = Admin.count
    @recent_logins = Admin.order(updated_at: :desc).limit(5)
  end

  def manage_members
    # Admin-only action for managing member roles
    unless current_admin.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
      return
    end

    # Load all users with their roles
    @users = Admin.all.order(:full_name, :email)
    @role_counts = {
      student: Admin.where(role: "student").count,
      advisor: Admin.where(role: "advisor").count,
      admin: Admin.where(role: "admin").count
    }
  end

  def update_roles
    # Admin-only action for updating user roles
    unless current_admin.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
      return
    end

    begin
      role_updates = params[:role_updates] || {}
      changes_made = 0
      successful_updates = []
      failed_updates = []

      if role_updates.empty?
        redirect_to manage_members_path, alert: "No role changes were submitted."
        return
      end

      ActiveRecord::Base.transaction do
        role_updates.each do |user_id, new_role|
          begin
            user = Admin.find(user_id.to_i)
            current_role = user.role || "student"

            # Skip if it's the current admin or if role is unchanged
            if user == current_admin
              next
            end

            if current_role == new_role
              next
            end

            if %w[student advisor admin].include?(new_role)
              user.update!(role: new_role)
              changes_made += 1
              successful_updates << "#{user.email}: #{current_role} → #{new_role}"
            else
              failed_updates << "#{user.email}: invalid role '#{new_role}'"
            end
          rescue ActiveRecord::RecordNotFound => e
            failed_updates << "User ID #{user_id}: not found"
          rescue => e
            Rails.logger.error "Error updating user #{user_id}: #{e.message}"
            failed_updates << "User ID #{user_id}: #{e.message}"
          end
        end
      end

      if changes_made > 0
        success_message = "Successfully updated #{changes_made} user role#{'s' if changes_made > 1}."
        if failed_updates.any?
          success_message += " Some updates failed: #{failed_updates.join(', ')}"
        end
        redirect_to manage_members_path, notice: success_message
      elsif failed_updates.any?
        error_message = "Role update errors: #{failed_updates.join(', ')}"
        redirect_to manage_members_path, alert: error_message
      else
        redirect_to manage_members_path, notice: "No role changes were needed."
      end

    rescue => e
      Rails.logger.error "Critical error in update_roles: #{e.message}"
      redirect_to manage_members_path, alert: "An error occurred while updating user roles. Please try again."
    end
  end

  def debug_users
    # Debug endpoint to check user roles
    unless current_admin.admin?
      render json: { error: "Access denied" }, status: 403
      return
    end

    users = Admin.all.map do |user|
      {
        id: user.id,
        email: user.email,
        full_name: user.full_name,
        role: user.role || "student",
        updated_at: user.updated_at
      }
    end

    render json: {
      users: users,
      role_counts: {
        student: Admin.where(role: "student").count,
        advisor: Admin.where(role: "advisor").count,
        admin: Admin.where(role: "admin").count
      },
      timestamp: Time.current
    }
  end
end
