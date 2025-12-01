# Handles student profile setup and account information display
class StudentProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_student_role
  skip_before_action :check_student_profile_complete, only: [ :edit, :update ]

  # Show account information
  def show
    @student = current_student
  end

  # First-time profile setup form
  def edit
    @student = current_student
    @advisors = Advisor.joins(:user).order("users.name ASC")
  end

  # Update profile information
  def update
    @student = current_student
    @advisors = Advisor.joins(:user).order("users.name ASC")

    # Update user name if provided
    if student_params[:name].present?
      @student.user.name = student_params[:name]
    end

    # Update student attributes
    @student.assign_attributes(student_params.except(:name))
    track_will_change = @student.will_save_change_to_track?
    had_assignments = @student.survey_assignments.exists?

    if @student.valid?(:profile_completion)
      @student.save!(context: :profile_completion) # This will also save the user and student changes

      if track_will_change || !had_assignments
        SurveyAssignments::AutoAssigner.call(student: @student)
      end

      redirect_to student_dashboard_path, notice: "Profile completed successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def ensure_student_role
    unless current_user&.role_student?
      redirect_to root_path, alert: "Access denied."
    end
  end

  def student_params
    params.require(:student).permit(:name, :uin, :major, :track, :advisor_id)
  end
end
