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
