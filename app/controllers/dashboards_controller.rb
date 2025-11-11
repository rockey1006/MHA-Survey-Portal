require "set"

# Presents role-aware dashboards and administrative utilities for students,
# advisors, and administrators within the main application.
class DashboardsController < ApplicationController
  skip_before_action :check_student_profile_complete, only: :switch_role
  before_action :ensure_profile_present, only: %i[student advisor]
  before_action :ensure_role_switch_allowed, only: :switch_role

  # Redirects the signed-in user to their primary role dashboard.
  #
  # @return [void]
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

       # ...existing code...
  end

  # Renders the student dashboard with survey completion summaries and
  # download links.
  #
  # @return [void]
  def student
    @student = current_student

    unless @student
      redirect_to dashboard_path, alert: "Student profile not found." and return
    end

    surveys = Survey.includes(:questions).ordered

    student_responses = StudentQuestion
                          .joins(question: :category)
                          .where(student_id: @student.student_id)
                          .where.not(response_value: [ nil, "" ])
                          .select(
                            "categories.survey_id AS survey_id",
                            "student_questions.question_id",
                            "student_questions.updated_at"
                          )

    responses_matrix = Hash.new { |hash, key| hash[key] = [] }
    student_responses.each do |entry|
      responses_matrix[entry.survey_id] << { question_id: entry.question_id, updated_at: entry.updated_at }
    end

    # Load assignment records to determine true completion (submit) status
    assignments = SurveyAssignment
                    .where(student_id: @student.student_id, survey_id: surveys.map(&:id))
                    .index_by(&:survey_id)

    @completed_surveys = []
    @pending_surveys = []

    surveys.each do |survey|
      required_ids = survey.questions.select { |question| required_question?(question) }.map(&:id)
      responses = responses_matrix[survey.id]
      answered_ids = responses.map { |entry| entry[:question_id] }.uniq
      # Only count answered questions that are required
      answered_required_count = (answered_ids & required_ids).size
      total_count = required_ids.present? ? required_ids.size : survey.questions.count
      # Only consider a survey "Completed" when it was submitted, not just answered
      assignment = assignments[survey.id]
      completed_at = assignment&.completed_at

      survey_response = SurveyResponse.build(student: @student, survey: survey)
      survey_summary = {
        survey: survey,
        answered_count: answered_required_count,
        total_count: total_count,
        completed_at: completed_at,
        required: required_ids.present?,
        survey_response: survey_response,
        download_token: survey_response.signed_download_token
      }

      if completed_at.present?
        @completed_surveys << survey_summary.merge(status: "Completed")
      else
        @pending_surveys << survey_summary.merge(status: "Pending")
      end
    end

    @dashboard_notifications = current_user.notifications.recent.limit(5)
  end

  # Displays advisor-specific information such as advisees and recent feedback.
  # Handles admin impersonation of advisor dashboards.
  #
  # @return [void]
  def advisor
    @advisor = current_advisor_profile
    admin_impersonating_advisor = current_user.admin_profile.present? && !current_user.role_admin?

    if admin_impersonating_advisor
      @advisees = Student.left_joins(:user).includes(:advisor).order(Arel.sql("LOWER(users.name) ASC"))
      @recent_feedback = Feedback.includes(:category, :survey, :student).order(created_at: :desc).limit(5)
      @pending_notifications_count = current_user.notifications.unread.count
    else
      @advisees = @advisor&.advisees&.includes(:user) || []
      @recent_feedback = Feedback.where(advisor_id: @advisor&.advisor_id).includes(:category, :survey, :student).order(created_at: :desc).limit(5)
      @pending_notifications_count = current_user.notifications.unread.count
    end

    @advisee_count = @advisees.size
    @active_survey_count = Survey.count
    advisee_ids = Array(@advisees).map(&:student_id).compact
    @total_reports = advisee_ids.empty? ? 0 : SurveyAssignment.where(student_id: advisee_ids).count
  end

  # Shows high-level system metrics for administrators.
  #
  # @return [void]
  def admin
    @role_counts = {
      student: User.students.count,
      advisor: User.advisors.count,
      admin: User.admins.count
    }

    @total_surveys = Survey.count
    @total_responses = StudentQuestion.count
    @total_reports = SurveyAssignment.count
    @recent_activity = build_recent_admin_activity
  end

  # Lists all members and role counts for admin management.
  #
  # @return [void]
  def manage_members
    ensure_admin!
    @users = User.order(:name, :email)
    @role_counts = {
      student: User.students.count,
      advisor: User.advisors.count,
      admin: User.admins.count
    }
  end

  # Applies role updates submitted by admins, reporting successes and failures.
  #
  # @return [void]
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
        user = User.find_by(id: user_id)
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

  # Returns a JSON payload summarizing users and role counts for troubleshooting.
  #
  # @return [void]
  def debug_users
    ensure_admin!

    users = User.order(:name).map do |user|
      {
        id: user.id,
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

  # Allows role switching in non-production environments for testing nested
  # dashboards.
  #
  # @return [void]
  def switch_role
    new_role = params[:role].to_s.downcase

    unless User.roles.values.include?(new_role)
      redirect_back fallback_location: dashboard_path, alert: "Unrecognized role selection." and return
    end

    if current_user.role == new_role
      redirect_to dashboard_path_for_role(new_role), notice: "Already viewing the #{new_role.titleize} dashboard." and return
    end

    begin
      current_user.update!(role: new_role)
      flash[:notice] = "Role switched to #{new_role.titleize} for testing."
    rescue StandardError => e
      Rails.logger.error "Role switch failed for user #{current_user.id}: #{e.message}"
      redirect_back fallback_location: dashboard_path, alert: "Unable to switch roles: #{e.message}" and return
    end

    redirect_to dashboard_path_for_role(new_role)
  end

  # Lists students and advisors for assignment management.
  #
  # @return [void]
  def manage_students
    @students = load_students
    @advisors = Advisor.left_joins(:user).includes(:user).order(Arel.sql("LOWER(users.name) ASC"))
    @advisor_select_options = [ [ "Unassigned", "" ] ] + @advisors.map { |advisor| [ advisor.display_name, advisor.advisor_id.to_s ] }
    @assignment_stats = {
      total: @students.size,
      assigned: @students.count { |student| student.advisor_id.present? },
      unassigned: @students.count { |student| student.advisor_id.blank? }
    }
    @can_manage = current_user.role_admin?
  end

  # Updates the advisor assigned to a student.
  #
  # @return [void]
  def update_student_advisor
    @student = Student.find(params[:id])
    if @student.update(student_params)
      redirect_to manage_students_path, notice: "Advisor updated successfully."
    else
      redirect_to manage_students_path, alert: "Failed to update advisor."
    end
  end

  # Applies bulk advisor assignments submitted from the management table.
  #
  # @return [void]
  def update_student_advisors
    return unless ensure_admin!

    advisor_updates = params[:advisor_updates] || {}
    if advisor_updates.blank?
      redirect_to manage_students_path, alert: "No advisor changes were submitted."
      return
    end

    advisor_ids = advisor_updates.values.filter_map { |value| value.presence&.to_i }
    advisor_lookup = Advisor.includes(:user).where(advisor_id: advisor_ids).index_by(&:advisor_id)

    successes = []
    failures = []

    ActiveRecord::Base.transaction do
      advisor_updates.each do |student_id, advisor_id_value|
        student = Student.includes(:user, advisor: :user).find_by(student_id: student_id)

        unless student
          failures << "Student ##{student_id} not found"
          next
        end

        normalized_advisor_id = advisor_id_value.presence&.to_i

        if normalized_advisor_id.present? && advisor_lookup[normalized_advisor_id].nil?
          failures << "#{student.user&.email || student.student_id}: advisor not found"
          next
        end

        current_advisor_id = student.advisor_id
        next if (current_advisor_id || nil) == normalized_advisor_id

        previous_label = student.advisor&.display_name || "Unassigned"
        new_advisor_record = normalized_advisor_id.present? ? advisor_lookup[normalized_advisor_id] : nil
        new_label = new_advisor_record&.display_name || "Unassigned"

        begin
          student.update!(advisor_id: normalized_advisor_id)
          successes << "#{student.user&.email || student.student_id}: #{previous_label} → #{new_label}"
        rescue StandardError => e
          failures << "#{student.user&.email || student.student_id}: #{e.message}"
        end
      end
    end

    if successes.present?
      message = "Updated #{successes.size} student advisor assignment#{'s' if successes.size != 1}."
      message += " Failures: #{failures.join(', ')}" if failures.present?
      redirect_to manage_students_path, notice: message
    elsif failures.present?
      redirect_to manage_students_path, alert: "Advisor update errors: #{failures.join(', ')}"
    else
      redirect_to manage_students_path, notice: "No advisor changes were needed."
    end
  end

  private

  # Ensures the current user has the necessary profile record for their role.
  #
  # @return [void]
  def ensure_profile_present
    return if current_user.role_admin?

    if current_user.role_student? && current_student.nil?
      current_user.create_student_profile unless current_user.student_profile
      @current_student = current_user.student_profile
    elsif current_user.role_advisor? && current_advisor_profile.nil?
      current_user.create_advisor_profile unless current_user.advisor_profile
      @current_advisor = current_user.advisor_profile
    end
  end

  # Raises an alert when a non-admin attempts to access admin-only actions.
  #
  # @return [Boolean] false when access is denied
  def ensure_admin!
    return true if current_user.role_admin?

    redirect_to dashboard_path, alert: "Access denied. Admin privileges required."
    false
  end

  # Gatekeeps the role-switch feature to development and test environments.
  #
  # @return [void]
  def ensure_role_switch_allowed
    # Always allow in development and test
    return if Rails.env.development? || Rails.env.test?

    # When ENABLE_ROLE_SWITCH=="1" the feature is explicitly enabled for this deployment.
    # In that mode, allow any signed-in user to use the switcher (useful for testing impersonation
    # flows across roles). If the flag is not set, deny access in production.
    if ENV["ENABLE_ROLE_SWITCH"] == "1" && current_user.present?
      return
    end

    redirect_to dashboard_path, alert: "Role switching is only available in development/test or when ENABLE_ROLE_SWITCH is enabled."
  end

  # Resolves the dashboard path for a given role value.
  #
  # @param role [String]
  # @return [String]
  def dashboard_path_for_role(role)
    case role
    when User.roles[:student]
      student_dashboard_path
    when User.roles[:advisor]
      advisor_dashboard_path
    when User.roles[:admin]
      admin_dashboard_path
    else
      dashboard_path
    end
  end

  # Determines whether a question must be answered to count toward completion.
  #
  # @param question [Question, nil]
  # @return [Boolean]
  def required_question?(question)
    return false unless question

    return true if question.required?

    return false unless question.question_type_multiple_choice?

    options = question.answer_options_list.map(&:strip).map(&:downcase)
    # Exception: flexibility scale questions (1-5) should remain optional
    is_flexibility_scale = (options == %w[1 2 3 4 5]) &&
                           question.question_text.to_s.downcase.include?("flexible")
    !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
  end


  # Loads students visible to the current user, respecting admin/advisor scope.
  #
  # @return [ActiveRecord::Relation<Student>]
  def load_students
    has_admin_privileges = current_user&.role_admin? || current_user&.admin_profile.present?

    scope = if has_admin_privileges
      Student.all
    else
      current_advisor_profile&.advisees || Student.none
    end

    scope
      .left_joins(:user)
      .includes(:user, advisor: :user)
      .order(Arel.sql("LOWER(users.name) ASC"))
  end

  # Strong parameters for assigning an advisor to a student.
  #
  # @return [ActionController::Parameters]
  def student_params
    params.require(:student).permit(:advisor_id)
  end

  # Builds a combined activity feed for the admin dashboard from several
  # operational data sources (survey changes, feedback, assignments, users).
  #
  # @return [Array<Hash>]
  def build_recent_admin_activity
    entries = []

    SurveyChangeLog
      .includes(:survey, :admin)
      .order(created_at: :desc)
      .limit(10)
      .each do |log|
        survey_title = log.survey&.title.presence || "Survey ##{log.survey_id}" || "Survey"
        admin_name = log.admin&.display_name.presence || log.admin&.email || "Admin"

        action_label = case log.action
        when "create" then "Survey created"
        when "update" then "Survey updated"
        when "archive" then "Survey archived"
        when "activate" then "Survey activated"
        when "assign" then "Survey assigned"
        when "delete" then "Survey deleted"
        when "preview" then "Survey previewed"
        else
          "Survey #{log.action}"
        end

        entries << {
          timestamp: log.created_at,
          icon: "📝",
          title: "#{action_label}: #{survey_title}",
          subtitle: log.description.presence || "#{admin_name} (#{log.action})",
          url: log.survey ? admin_survey_path(log.survey) : nil
        }
      end

    Feedback
      .includes(:survey, :category, advisor: :user, student: :user)
      .order(updated_at: :desc)
      .limit(10)
      .each do |feedback|
        student_name = feedback.student&.user&.name.presence || "Student ##{feedback.student_id}" || "Student"
        advisor_name = feedback.advisor&.display_name.presence || feedback.advisor&.email || "Advisor"
        survey_title = feedback.survey&.title.presence || "Survey ##{feedback.survey_id}" || "Survey"

        entries << {
          timestamp: feedback.updated_at,
          icon: "💬",
          title: "Feedback updated: #{student_name}",
          subtitle: "#{advisor_name} on #{survey_title}",
          url: feedback.survey && feedback.student ? new_feedback_path(survey_id: feedback.survey_id, student_id: feedback.student_id, prefill: true) : nil
        }
      end

    SurveyAssignment
      .includes(:survey, advisor: :user, student: :user)
      .order(updated_at: :desc)
      .limit(10)
      .each do |assignment|
        survey_title = assignment.survey&.title.presence || "Survey ##{assignment.survey_id}" || "Survey"
        student_name = assignment.student&.user&.name.presence || "Student ##{assignment.student_id}" || "Student"
        advisor_name = assignment.advisor&.display_name.presence || assignment.advisor&.email || "Advisor"
        due_label = assignment.due_date.present? ? l(assignment.due_date.to_date, format: :long) : "No due date"

        entries << {
          timestamp: assignment.updated_at,
          icon: "📬",
          title: "Survey assigned: #{survey_title}",
          subtitle: "#{student_name} · Advisor: #{advisor_name} · Due #{due_label}",
          url: student_records_path
        }
      end

    User
      .order(created_at: :desc)
      .limit(5)
      .each do |user|
        entries << {
          timestamp: user.created_at,
          icon: "👤",
          title: "New user: #{user.display_name}",
          subtitle: user.email,
          url: manage_members_path
        }
      end

    entries
      .compact
      .sort_by { |entry| entry[:timestamp] || Time.zone.at(0) }
      .reverse
      .first(12)
  end
end
