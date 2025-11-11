# db/seeds.rb
require "json"
require "yaml"
require "active_support/core_ext/numeric/time"

puts "\n== Seeding Health sample data =="

previous_queue_adapter = ActiveJob::Base.queue_adapter

unless Rails.env.test?
  ActiveJob::Base.queue_adapter = :inline
  at_exit { ActiveJob::Base.queue_adapter = previous_queue_adapter }
end

Rails.cache.clear

seed_user = lambda do |email:, name:, role:, uid: nil, avatar_url: nil|
  role_value = User.normalize_role(role) || role.to_s
  user = User.find_or_initialize_by(email: email)
  user.name = name
  user.uid = uid.presence || user.uid.presence || email
  user.avatar_url = avatar_url if avatar_url.present?
  user.role = role_value
  user.save!
  user.send(:ensure_role_profile!)
  user
end

puts "• Creating administrative accounts"
admin_accounts = [
  { email: "health-admin1@tamu.edu", name: "Health Admin One" },
  { email: "health-admin2@tamu.edu", name: "Health Admin Two" },
  { email: "health-admin3@tamu.edu", name: "Health Admin Three" }
]

admin_users = admin_accounts.map do |attrs|
  seed_user.call(email: attrs[:email], name: attrs[:name], role: :admin)
end

puts "• Creating advisor accounts"
advisor_users = [
  seed_user.call(email: "rainsuds@tamu.edu", name: "Tee Li", role: :advisor),
  seed_user.call(email: "advisor.clark@tamu.edu", name: "Jordan Clark", role: :advisor)
]

advisors = advisor_users.map(&:advisor_profile)

puts "• Creating sample students"
students_seed = [
  { email: "avery.harrison25@tamu.edu", name: "Avery Harrison", track: "Residential", advisor: advisors.first },
  { email: "liam.daniels25@tamu.edu", name: "Liam Daniels", track: "Residential", advisor: advisors.first },
  { email: "zoe.elliott24@tamu.edu", name: "Zoe Elliott", track: "Residential", advisor: advisors.first },
  { email: "mila.perez25@tamu.edu", name: "Mila Perez", track: "Executive", advisor: advisors.last },
  { email: "carter.andrews25@tamu.edu", name: "Carter Andrews", track: "Executive", advisor: advisors.last },
  { email: "sloan.reese24@tamu.edu", name: "Sloan Reese", track: "Executive", advisor: advisors.last },
  { email: "nova.mitchell25@tamu.edu", name: "Nova Mitchell", track: "Residential", advisor: advisors.first },
  { email: "emery.walsh24@tamu.edu", name: "Emery Walsh", track: "Residential", advisor: advisors.first },
  { email: "kiara.hughes25@tamu.edu", name: "Kiara Hughes", track: "Executive", advisor: advisors.last },
  { email: "judah.nguyen24@tamu.edu", name: "Judah Nguyen", track: "Executive", advisor: advisors.last }
]

students = students_seed.map do |attrs|
  user = seed_user.call(email: attrs[:email], name: attrs[:name], role: :student)
  profile = user.student_profile || Student.new(student_id: user.id)
  profile.assign_attributes(track: attrs[:track], advisor: attrs[:advisor])
  # Bypass validations for seed data; first-login flow will collect required fields
  profile.save!(validate: false)
  profile
end

high_performer_emails = %w[
  nova.mitchell25@tamu.edu
  emery.walsh24@tamu.edu
  kiara.hughes25@tamu.edu
]
high_performers = students.select { |student| high_performer_emails.include?(student.user.email) }
high_performer_ids = high_performers.map(&:student_id)

puts "• Loading program survey templates"
survey_template_path = Rails.root.join("db", "data", "program_surveys.yml")
unless File.exist?(survey_template_path)
  raise "Survey template data file not found: #{survey_template_path}. Please ensure the survey definitions are available."
end

template_data = YAML.safe_load_file(survey_template_path)
survey_templates = Array(template_data.fetch("surveys"))

answer_options_for = lambda do |options|
  return nil if options.blank?

  Array(options).map(&:to_s).reject(&:blank?).to_json
end

created_surveys = []
surveys_by_track = Hash.new { |hash, key| hash[key] = [] }

survey_templates.each do |definition|
  title = definition.fetch("title")
  semester = definition.fetch("semester")
  puts "   • Ensuring survey: #{title} (#{semester})"

  Survey.transaction do
    survey = Survey.find_or_initialize_by(title:, semester:)
    survey.creator ||= admin_users.first
    survey.description = definition["description"]
    survey.is_active = definition.fetch("is_active", true)

    survey.categories.destroy_all if survey.persisted?
    survey.categories.reset

    categories = Array(definition.fetch("categories", []))
    categories.each do |category_definition|
      category = survey.categories.build(
        name: category_definition.fetch("name"),
        description: category_definition["description"]
      )

      Array(category_definition.fetch("questions", [])).each do |question_definition|
        category.questions.build(
          question_text: question_definition.fetch("text"),
          question_order: question_definition.fetch("order"),
          question_type: question_definition.fetch("type"),
          is_required: question_definition.fetch("required", false),
          has_evidence_field: question_definition.fetch("has_evidence_field", false),
          answer_options: answer_options_for.call(question_definition["options"])
        )
      end
    end

    survey.save!

    tracks = Array(definition.fetch("tracks", [])).map(&:to_s)
    survey.assign_tracks!(tracks)

    created_surveys << survey
    tracks.each do |track|
      normalized_track = track.to_s.strip.downcase
      surveys_by_track[normalized_track] << survey
    end
  end
end

puts "• Assigning surveys to each student"
response_rng = Random.new(20_251_110)

sample_numeric = lambda do |min:, max:|
  value = response_rng.rand(min..max)
  # Keep one decimal place for readability
  format("%.1f", value.round(1))
end

sample_timestamp = lambda do
  # Spread responses over roughly the last 18 months for chart trends
  months_ago = response_rng.rand(0..18)
  days_offset = response_rng.rand(0..28)
  Time.zone.now - months_ago.months - days_offset.days
end

sample_text = lambda do |question|
  base = case question.question_type
         when "short_answer"
           "Reflection on #{question.question_text.downcase}".squish
         else
           "Response for #{question.question_text.downcase}".squish
         end
  suffix = ["highlighted progress", "noted opportunities", "summarized outcomes", "flagged next steps", "shared learnings"].sample(random: response_rng)
  "#{base} — #{suffix}."
end

drive_links = %w[
  https://drive.google.com/file/d/1AbCdEf12345/view?usp=drive_link
  https://drive.google.com/drive/folders/1ExampleFolderId?usp=drive_link
  https://docs.google.com/document/d/1SampleDocumentId/edit?usp=drive_link
]

competency_category_names = [
  "Health Care Environment and Community",
  "Leadership Skills",
  "Management Skills",
  "Analytic and Technical Skills",
  "Mentor Relationships (RMHA Only)",
  "Semester"
].freeze

students.each do |student|
  track_value = student.track.presence || student.read_attribute(:track)
  normalized_student_track = track_value.to_s.strip.downcase
  next if normalized_student_track.blank?

  Array(surveys_by_track[normalized_student_track]).each do |survey|
    survey.questions.order(:question_order).each do |question|
      record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question.id)

      response_roll = response_rng.rand
      advisor_profile = student.advisor

      # Decide whether this entry is captured as a student reflection or advisor evaluation
      record.advisor_id = case response_roll
                          when 0.0..0.20
                            nil
                          when 0.20..0.65
                            nil
                          else
                            advisor_profile&.advisor_id
                          end

      response_value = nil
      if high_performer_ids.include?(student.student_id)
        response_value = case question.question_type
                         when "evidence"
                           drive_links.first
                         when "multiple_choice"
                           "Yes"
                         when "short_answer"
                           if competency_category_names.include?(question.category.name) && question.question_order == 1
                             "4.8"
                           else
                             "Delivered an exceptional outcome that exceeded expectations."
                           end
                         else
                           "Completed with distinction."
                         end
        record.advisor_id ||= advisor_profile&.advisor_id
      else
        case question.question_type
        when "evidence"
          response_value = drive_links.sample(random: response_rng)
        when "multiple_choice"
          options = begin
            raw = question.answer_options.presence || "[]"
            parsed = JSON.parse(raw)
            Array.wrap(parsed)
          rescue JSON::ParserError
            []
          end
          response_value = options.sample(random: response_rng).presence || "Yes"
        when "short_answer"
          if competency_category_names.include?(question.category.name) && question.question_order == 1
            # First question in competency-style categories drives numeric analytics
            min, max = record.advisor_id.present? ? [3.2, 4.9] : [2.5, 4.5]
            response_value = sample_numeric.call(min:, max:)
          else
            response_value = sample_text.call(question)
          end
        else
          response_value = sample_text.call(question)
        end
      end

      # Introduce the occasional "not assessed" entry for advisors (skip top performers)
      if record.advisor_id.present? && response_roll < 0.28 && !high_performer_ids.include?(student.student_id)
        response_value = nil
      end

      # Spread timestamps so reports show multiple cohorts/timepoints
      timestamp = sample_timestamp.call
      record.created_at ||= timestamp
      record.updated_at = timestamp

      record.response_value = response_value
      record.save!
    end

    assignment = SurveyAssignment.find_or_initialize_by(survey:, student:)
    assignment.advisor ||= student.advisor
    assignment.assigned_at ||= Time.zone.now
    assignment.due_date ||= 2.weeks.from_now

    created_assignment = assignment.new_record?
    assignment.save! if assignment.new_record? || assignment.changed?

    if created_assignment
      SurveyNotificationJob.perform_now(event: :assigned, survey_assignment_id: assignment.id)
    end

    puts "   • Prepared #{survey.questions.count} questions and assignment for #{student.user.name} (#{track_value})"
  puts "     ↳ High performer calibration applied" if high_performer_ids.include?(student.student_id)
    puts "     ↳ Due #{assignment.due_date&.to_date}#{' (new notification queued)' if created_assignment}"
  end
end

puts "   • Generated sample ratings for #{StudentQuestion.count} question responses"

puts "🎉 Seed data finished!"
