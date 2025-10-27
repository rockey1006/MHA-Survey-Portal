# Dispatches notification events related to survey assignments and lifecycle changes.
class SurveyNotificationJob < ApplicationJob
  queue_as :default

  rescue_from ActiveRecord::RecordNotFound do |error|
    Rails.logger.warn("SurveyNotificationJob skipped: #{error.message}")
  end

  # @param event [Symbol, String]
  # @param survey_assignment_id [Integer, nil]
  # @param survey_id [Integer, nil]
  # @param user_id [Integer, nil]
  # @param metadata [Hash]
  # @return [void]
  def perform(event:, survey_assignment_id: nil, survey_id: nil, user_id: nil, metadata: {})
    event_key = event.to_sym

    case event_key
    when :assigned
      handle_assigned_notification(survey_assignment_id)
    when :due_soon
      handle_due_soon_notification(survey_assignment_id)
    when :past_due
      handle_past_due_notification(survey_assignment_id)
    when :completed
      handle_completed_notification(survey_assignment_id)
    when :survey_updated
      handle_survey_updated_notification(survey_id, metadata)
    when :survey_archived
      handle_survey_archived_notification(survey_id)
    when :custom
      handle_custom_notification(user_id, metadata)
    else
      Rails.logger.info("SurveyNotificationJob received unknown event: #{event_key}")
    end
  end

  private

  def handle_assigned_notification(survey_assignment_id)
    assignment = SurveyAssignment.includes(:survey, student: :user, advisor: :user).find(survey_assignment_id)
    advisor_name = assignment.advisor&.user&.display_name || "Your advisor"

    Notification.deliver!(
      user: assignment.recipient_user,
      title: "New Survey Assigned",
      message: "#{advisor_name} assigned the survey '#{assignment.survey.title}' to you.",
      notifiable: assignment
    )
  end

  def handle_due_soon_notification(survey_assignment_id)
    assignment = SurveyAssignment.includes(:survey, student: :user).find(survey_assignment_id)
    return if assignment.completed_at?
    return unless assignment.due_date

    due_in = ActionController::Base.helpers.distance_of_time_in_words(Time.current, assignment.due_date)

    Notification.deliver!(
      user: assignment.recipient_user,
      title: "Survey Due Soon",
      message: "Your survey '#{assignment.survey.title}' is due in #{due_in}. Please complete it before the deadline.",
      notifiable: assignment
    )
  end

  def handle_past_due_notification(survey_assignment_id)
    assignment = SurveyAssignment.includes(:survey, student: :user).find(survey_assignment_id)
    return if assignment.completed_at?
    return unless assignment.due_date

    Notification.deliver!(
      user: assignment.recipient_user,
      title: "Survey Past Due",
      message: "The survey '#{assignment.survey.title}' is past due. Please complete it as soon as possible.",
      notifiable: assignment
    )
  end

  def handle_completed_notification(survey_assignment_id)
    assignment = SurveyAssignment.includes(:survey, advisor: :user, student: :user).find(survey_assignment_id)
    return unless (advisor_user = assignment.advisor_user)

    Notification.deliver!(
      user: advisor_user,
      title: "Student Survey Completed",
      message: "#{assignment.student.full_name} completed '#{assignment.survey.title}'.",
      notifiable: assignment
    )
  end

  def handle_survey_updated_notification(survey_id, metadata)
    survey = Survey.find(survey_id)
    advisor_ids = SurveyAssignment.where(survey_id: survey_id).distinct.pluck(:advisor_id).compact

    User.where(id: advisor_ids).find_each do |advisor_user|
      Notification.deliver!(
        user: advisor_user,
        title: "Survey Updated",
        message: "The survey '#{survey.title}' has been updated. #{metadata[:summary]}".strip,
        notifiable: survey
      )
    end
  end

  def handle_survey_archived_notification(survey_id)
    survey = Survey.find(survey_id)
    student_ids = SurveyAssignment.where(survey_id: survey_id).distinct.pluck(:student_id)

    Student.includes(:user).where(student_id: student_ids).find_each do |student|
      Notification.deliver!(
        user: student.user,
        title: "Survey Archived",
        message: "The survey '#{survey.title}' is no longer active.",
        notifiable: survey
      )
    end
  end

  def handle_custom_notification(user_id, metadata)
    return if user_id.blank?

    user = User.find(user_id)
    title = metadata[:title] || "Notification"
    message = metadata[:message] || "You have a new notification."
    Notification.deliver!(user: user, title: title, message: message)
  end
end
