# db/seeds.rb
require "json"
require "yaml"
require "active_support/core_ext/numeric/time"
require "set"

puts "\n== Seeding Health sample data =="

previous_queue_adapter = ActiveJob::Base.queue_adapter
seed_async_adapter = nil

unless Rails.env.test?
  # Use a dedicated async adapter during seeding so notification jobs run concurrently
  # while still flushing before the process exits.
  seed_async_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new(min_threads: 2, max_threads: 4, idletime: 1.second)
  ActiveJob::Base.queue_adapter = seed_async_adapter
  at_exit do
    seed_async_adapter&.shutdown if seed_async_adapter.respond_to?(:shutdown)
    ActiveJob::Base.queue_adapter = previous_queue_adapter
  end
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
          description: question_definition["description"],
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

semester_names = survey_templates.map { |definition| definition["semester"].to_s.strip.presence }.compact.uniq
if semester_names.blank?
  semester_names = [Time.zone.now.strftime("%B %Y")]
end

puts "• Syncing program semesters"
ProgramSemester.transaction do
  target_current = semester_names.last
  semester_names.each do |name|
    ProgramSemester.find_or_create_by!(name: name)
  end

  ProgramSemester.where.not(name: target_current).update_all(current: false)
  ProgramSemester.find_by(name: target_current)&.update!(current: true)
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

competency_titles = Reports::DataAggregator::COMPETENCY_TITLES
competency_title_lookup = competency_titles.map { |title| title.to_s.strip }.to_set

competency_rating_value = lambda do |high_performer:|
  pool = if high_performer
           [4, 4, 5, 5, 5]
         else
           [2, 3, 3, 4, 4, 5]
         end
  pool.sample(random: response_rng).to_s
end

students.each do |student|
  track_value = student.track.presence || student.read_attribute(:track)
  normalized_student_track = track_value.to_s.strip.downcase
  next if normalized_student_track.blank?

  Array(surveys_by_track[normalized_student_track]).each do |survey|
    survey.questions.order(:question_order).each do |question|
      record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question.id)

      response_roll = response_rng.rand
      advisor_profile = student.advisor
      question_label = question.question_text.to_s.strip
      is_competency_question = competency_title_lookup.include?(question_label)
      high_performer = high_performer_ids.include?(student.student_id)

      # Ensure competency metrics always capture a student self-rating entry
      record.advisor_id = if is_competency_question
                            nil
                          else
                            case response_roll
                            when 0.0..0.20
                              nil
                            when 0.20..0.65
                              nil
                            else
                              advisor_profile&.advisor_id
                            end
                          end

      response_value = case question.question_type
                       when "evidence"
                         high_performer ? drive_links.first : drive_links.sample(random: response_rng)
                       when "multiple_choice"
                         options = begin
                           raw = question.answer_options.presence || "[]"
                           parsed = JSON.parse(raw)
                           Array.wrap(parsed)
                         rescue JSON::ParserError
                           []
                         end

                         if is_competency_question
                           rating_value = competency_rating_value.call(high_performer: high_performer)
                           options.include?(rating_value) ? rating_value : (options.sample(random: response_rng).presence || rating_value || "3")
                         else
                           preferred = high_performer ? "Yes" : nil
                           selection = options.sample(random: response_rng).presence
                           fallback = preferred && options.include?(preferred) ? preferred : selection
                           fallback.presence || preferred || options.first || "Yes"
                         end
                       when "short_answer"
                         if is_competency_question
                           competency_rating_value.call(high_performer: high_performer)
                         else
                           high_performer ? "Delivered an exceptional outcome that exceeded expectations." : sample_text.call(question)
                         end
                       else
                         high_performer ? "Completed with distinction." : sample_text.call(question)
                       end

      record.advisor_id ||= advisor_profile&.advisor_id if high_performer && !is_competency_question

      # Introduce the occasional "not assessed" entry for advisors (skip top performers)
      if !is_competency_question && record.advisor_id.present? && response_roll < 0.28 && !high_performer_ids.include?(student.student_id)
        response_value = nil
      end

      # Spread timestamps so reports show multiple cohorts/timepoints
      timestamp = sample_timestamp.call
      record.created_at ||= timestamp
      record.updated_at = timestamp

      record.response_value = response_value
      record.save!
    end

    puts "   • Prepared #{survey.questions.count} questions for #{student.user.name} (#{track_value})"
    puts "     ↳ High performer calibration applied" if high_performer_ids.include?(student.student_id)
    puts "     ↳ Track auto-assign will create survey tasks on next profile update"
  end
end

puts "   • Generated sample ratings for #{StudentQuestion.count} question responses"

puts "🎉 Seed data finished!"
