# Rake tasks to preview and optionally delete evidence questions for specific categories.
# Usage:
# 1) Preview candidates:
#    rake db:preview_evidence_questions
#    -> writes tmp/evidence_questions_backup.csv and prints a summary
# 2) Delete candidates (destructive):
#    CONFIRM=yes rake db:delete_evidence_questions
#    -> deletes only the IDs listed in the preview and logs the deletion

namespace :db do
  desc "Preview evidence questions to delete and write a backup CSV to tmp/evidence_questions_backup.csv"
  task preview_evidence_questions: :environment do
    require "csv"

    categories = [ "Semester", "Mentor Relationships (RMHA Only)", "Volunteering/Service" ]
    puts "Previewing evidence questions for categories: #{categories.join(', ')}"

    qs = Question.joins(:category).where(categories: { name: categories }, question_type: "evidence")
    puts "Found #{qs.count} evidence question(s) matching categories. Writing backup to tmp/evidence_questions_backup.csv"

    FileUtils.mkdir_p(Rails.root.join("tmp"))
    CSV.open(Rails.root.join("tmp", "evidence_questions_backup.csv"), "w") do |csv|
      csv << %w[id category_id category_name question_text created_at updated_at]
      qs.find_each do |q|
        csv << [ q.id, q.category_id, q.category.name, q.question, q.created_at, q.updated_at ]
      end
    end

    puts "Preview written. To delete these questions run: CONFIRM=yes rake db:delete_evidence_questions"
  end

  desc "Delete evidence questions previously previewed (destructive). Requires CONFIRM=yes."
  task delete_evidence_questions: :environment do
    unless ENV["CONFIRM"] == "yes"
      puts "This task is destructive. To proceed set CONFIRM=yes"
      exit 1
    end

    backup_path = Rails.root.join("tmp", "evidence_questions_backup.csv")
    unless File.exist?(backup_path)
      puts "Backup file not found at #{backup_path}. Run rake db:preview_evidence_questions first."
      exit 1
    end

    require "csv"
    ids = CSV.read(backup_path, headers: true).map { |r| r["id"].to_i }
    puts "Deleting #{ids.size} questions: #{ids.join(', ')}"

    ActiveRecord::Base.transaction do
      # Soft-delete? We'll remove rows from questions table and their dependent student_questions
      StudentQuestion.where(question_id: ids).delete_all
      Question.where(id: ids).delete_all
    end

    puts "Deletion complete. Backup remains at #{backup_path}."
  end
end
