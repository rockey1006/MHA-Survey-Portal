namespace :notifications do
  desc "Enqueue notifications for surveys approaching or exceeding their due date"
  task send_due_reminders: :environment do
    SurveyAssignmentNotifier.run_due_date_checks!
    puts "Queued due soon and overdue survey notifications"
  end
end
