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
    if @student.assign_attributes(student_params.except(:name)) && @student.valid?(:profile_completion)
      @student.save!(context: :profile_completion) # This will also save the user changes
      @student.save! # This will also save the user changes

      # Automatic Survey Assignment: assign surveys matching the student's track
      if @student.track.present?
        surveys = Survey.joins(:survey_assignments).where(survey_assignments: { track: @student.track }).distinct
        surveys.find_each do |survey|
          survey.questions.order(:question_order).each do |question|
            StudentQuestion.find_or_create_by!(student_id: @student.student_id, question_id: question.id) do |record|
              record.advisor_id = @student.advisor_id
            end
          end
        end
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
