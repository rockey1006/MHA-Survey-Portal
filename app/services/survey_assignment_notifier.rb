# Utility class for enqueuing notification jobs related to survey assignments.
class SurveyAssignmentNotifier
  DUE_SOON_WINDOW = 3.days

  class << self
    # Enqueues notifications for assignments closing soon or already closed.
    #
    # @param reference_time [Time] point-in-time used for calculations
    # @return [void]
    def run_due_date_checks!(reference_time: Time.current)
      scope = SurveyAssignment.incomplete.where.not(available_until: nil)

      closing_soon_scope = scope.where(available_until: reference_time..(reference_time + DUE_SOON_WINDOW))
      closing_soon_scope.find_each do |assignment|
        SurveyNotificationJob.perform_later(event: :due_soon, survey_assignment_id: assignment.id)
      end

      closed_scope = scope.where("available_until < ?", reference_time)
      closed_scope.find_each do |assignment|
        SurveyNotificationJob.perform_later(event: :past_due, survey_assignment_id: assignment.id)
      end
    end

    # Sends a single notification immediately without background work.
    #
    # @param assignment [SurveyAssignment]
    # @param title [String]
    # @param message [String]
    # @return [Notification]
    def notify_now!(assignment:, title:, message:)
      Notification.deliver!(user: assignment.recipient_user, title: title, message: message, notifiable: assignment)
    end
  end
end
