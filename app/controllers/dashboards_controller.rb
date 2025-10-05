class DashboardsController < ApplicationController
  before_action :ensure_profile_present, only: %i[student advisor]

  def show
    case current_user.role
    when "student"
      redirect_to student_dashboard_path
    when "advisor"
      redirect_to advisor_dashboard_path
    when "admin"
      redirect_to admin_dashboard_path
    else
      redirect_to student_dashboard_path
    end
  end

  def student
  @student = current_student
  responses = @student.survey_responses.includes(:survey)
  @pending_survey_responses = responses.pending
  @completed_survey_responses = responses.completed
  @pending_surveys = Survey.where(id: @pending_survey_responses.pluck(:survey_id))
  @completed_surveys = Survey.where(id: @completed_survey_responses.pluck(:survey_id))
  end

  def advisor
    @advisor = current_advisor_profile || current_user.admin_profile&.user&.advisor_profile
    @advisees = @advisor&.advisees&.includes(:user) || []
    @recent_feedback = Feedback.where(advisor_id: @advisor&.advisor_id).order(created_at: :desc).limit(5).includes(:category, :survey_response)
    @advisee_count = @advisees.size
    @active_survey_count = Survey.count
    @pending_notifications_count = if @advisor
      SurveyResponse.where(advisor_id: @advisor.advisor_id).pending.count
    else
      0
    end
  end

  def admin
    @role_counts = {
      student: User.students.count,
      advisor: User.advisors.count,
      admin: User.admins.count
    }

    @total_surveys = Survey.count
    @total_responses = SurveyResponse.count
    @recent_logins = User.order(updated_at: :desc).limit(5)
  end

  def manage_members
    ensure_admin!
    @users = User.order(:name, :email)
    @role_counts = {
      student: User.students.count,
      advisor: User.advisors.count,
      admin: User.admins.count
    }
  end

  def update_roles
    ensure_admin!

    role_updates = params[:role_updates] || {}
    if role_updates.empty?
      redirect_to manage_members_path, alert: "No role changes were submitted."
      return
    end

    allowed_roles = User.roles.values
    successful_updates = []
    failed_updates = []

    ActiveRecord::Base.transaction do
      role_updates.each do |user_id, new_role|
        user = User.find_by(user_id: user_id)
        unless user
          failed_updates << "User ID #{user_id}: not found"
          next
        end

        if user == current_user
          failed_updates << "#{user.email}: cannot change your own role"
          next
        end

        unless allowed_roles.include?(new_role)
          failed_updates << "#{user.email}: invalid role '#{new_role}'"
          next
        end

        next if user.role == new_role

        previous_role = user.role
        user.update!(role: new_role)
        successful_updates << "#{user.email}: #{previous_role} → #{new_role}"
      rescue StandardError => e
        Rails.logger.error "Error updating user #{user_id}: #{e.message}"
        failed_updates << "User ID #{user_id}: #{e.message}"
      end
    end

    if successful_updates.present?
      message = "Updated #{successful_updates.size} user role#{'s' if successful_updates.size > 1}."
      message += " Failures: #{failed_updates.join(', ')}" if failed_updates.present?
      redirect_to manage_members_path, notice: message
    elsif failed_updates.present?
      redirect_to manage_members_path, alert: "Role update errors: #{failed_updates.join(', ')}"
    else
      redirect_to manage_members_path, notice: "No role changes were needed."
    end
  end

  def debug_users
    ensure_admin!

    users = User.order(:name).map do |user|
      {
        id: user.user_id,
        email: user.email,
        name: user.name,
        role: user.role,
        updated_at: user.updated_at
      }
    end

    render json: {
      users: users,
      role_counts: {
        student: User.students.count,
        advisor: User.advisors.count,
        admin: User.admins.count
      },
      timestamp: Time.current
    }
  end

  private

  def ensure_profile_present
    return if current_user.role_admin?

    if current_user.role_student? && current_student.nil?
      current_user.create_student_profile unless current_user.student_profile
    elsif current_user.role_advisor? && current_advisor_profile.nil?
      current_user.create_advisor_profile unless current_user.advisor_profile
    end
  end

  def ensure_admin!
    return if current_user.role_admin?

    redirect_to dashboard_path, alert: "Access denied. Admin privileges required."
    false
  end

  def ensure_demo_surveys_for(student)
    return unless student

    sample_surveys.each do |survey_attrs|
      survey = Survey.find_or_create_by!(survey_attrs.slice(:title, :semester))
      category = survey.categories.find_or_create_by!(name: survey_attrs[:category_name]) do |cat|
        cat.description = survey_attrs[:category_description]
      end

      ensure_questions_for(category, survey_attrs[:questions])

      SurveyResponse.find_or_create_by!(student_id: student.id, survey_id: survey.id) do |response|
        response.advisor_id = student.advisor_id
        response.status = SurveyResponse.statuses[:not_started]
      end
    end
  end

  def sample_surveys
    [
      {
        title: "Health & Wellness Survey",
        semester: "Fall 2025",
        category_name: "Wellness",
        category_description: "Student health and wellbeing",
        questions: [
          { order: 1, type: :multiple_choice, text: "How would you rate your current stress level?", options: "Low,Moderate,High" },
          { order: 2, type: :scale, text: "On a scale from 1-5, how satisfied are you with your work-life balance?", options: "1,2,3,4,5" },
          { order: 3, type: :short_answer, text: "Describe one strategy you use to maintain your wellbeing." },
          { order: 4, type: :evidence, text: "Upload evidence supporting your wellness activities." }
        ]
      },
      {
        title: "Career Goals Survey",
        semester: "Fall 2025",
        category_name: "Professional Development",
        category_description: "Goals and milestones toward career objectives",
        questions: [
          { order: 1, type: :multiple_choice, text: "Which industry are you targeting after graduation?", options: "Finance,Technology,Consulting,Other" },
          { order: 2, type: :short_answer, text: "What is your top career goal for the next six months?" },
          { order: 3, type: :scale, text: "Rate your confidence in achieving this goal.", options: "1,2,3,4,5" }
        ]
      }
    ]
  end

  def ensure_questions_for(category, questions)
    questions.each do |question_attrs|
  question = category.questions.find_or_initialize_by(question_order: question_attrs[:order])
  question.question = question_attrs[:text]
  question.question_type = question_attrs[:type]
  question.answer_options = question_attrs[:options]
  question.save!
    end
  end
end
