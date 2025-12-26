# db/seeds.rb
require "json"
require "yaml"
require "active_support/core_ext/numeric/time"
require "set"
require "active_record/tasks/database_tasks"
require "stringio"

_seed_original_stdout = $stdout
_seed_silence_stdout = Rails.env.test? || ENV["QUIET_SEEDS"].present?
$stdout = StringIO.new if _seed_silence_stdout
begin

puts "\n== Seeding =="

def ensure_schema_loaded!
  connection = ActiveRecord::Base.connection

  return if connection.data_source_exists?("users")

  puts "• Running migrations"
  ActiveRecord::Tasks::DatabaseTasks.migrate
  ActiveRecord::Base.connection_pool.disconnect!
  ActiveRecord::Base.establish_connection
rescue StandardError => e
  warn "Unable to load schema automatically: #{e.message}"
  raise
end

ensure_schema_loaded!

# Majors
if ActiveRecord::Base.connection.data_source_exists?("majors")
  Major.find_or_create_by!(name: "Health Administration")
end

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

begin
  connection = ActiveRecord::Base.connection
  has_solid_cache = connection.data_source_exists?("solid_cache_entries")

  if has_solid_cache
    Rails.cache.clear
  else
    puts "• Skipping cache clear (solid_cache_entries table not present)"
  end
rescue ActiveRecord::StatementInvalid => e
  warn "• Skipping cache clear (cache schema not loaded yet): #{e.message}"
end

# Demo/test seed data (sample users + generated responses) is intentionally
# disabled in production unless explicitly enabled.
# - Default: enabled in non-production, disabled in production.
# - Override: set SEED_DEMO_DATA=1 (or true/yes) to enable even in production.
#             set SEED_DEMO_DATA=0 (or false/no) to force-disable.
seed_demo_data = !Rails.env.production?
if ENV.key?("SEED_DEMO_DATA")
  raw = ENV["SEED_DEMO_DATA"].to_s.strip.downcase
  seed_demo_data = %w[1 true yes y on].include?(raw)
end
puts "• Skipping demo/test seed data" unless seed_demo_data

admin_users = []
advisors = []
students = []
pending_student_ids = []
multi_semester_student_ids = []

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

if seed_demo_data
  puts "• Creating administrative accounts"
  admin_accounts = [
    # { email: "health-admin1@tamu.edu", name: "Health Admin One" }
  ]

  admin_users = admin_accounts.map do |attrs|
    seed_user.call(email: attrs[:email], name: attrs[:name], role: :admin)
  end

  if admin_users.empty?
    admin_users << seed_user.call(email: "admin@tamu.edu", name: "MHA Admin", role: :admin)
  end

  puts "• Creating advisor accounts"
  advisor_users = [
    seed_user.call(email: "rainsuds@tamu.edu", name: "Tee Li", role: :advisor),
    seed_user.call(email: "advisor.clark@tamu.edu", name: "Jordan Clark", role: :advisor)
  ]

  advisors = advisor_users.map(&:advisor_profile)
  advisors_by_email = advisor_users.index_by { |user| user.email.to_s.downcase }

  puts "• Creating sample students"
  students_data_path = Rails.root.join("db", "data", "sample_students.yml")
  unless File.exist?(students_data_path)
    raise "Sample students data file not found: #{students_data_path}."
  end

  students_seed = Array(YAML.safe_load_file(students_data_path))
  students_with_metadata = students_seed.map do |attrs|
    data = attrs.is_a?(Hash) ? attrs : {}
    email = data.fetch("email")
    name = data.fetch("name")
    track = data.fetch("track")
    advisor_email = data.fetch("advisor_email")
    pending = data.fetch("pending", false)
    program_year = data.fetch("program_year", 1)
    multi_semester = if data.key?("multi_semester")
      data.fetch("multi_semester")
    else
      program_year.to_i == 2
    end

    advisor_user = advisors_by_email[advisor_email.to_s.downcase]
    raise "Unknown advisor_email #{advisor_email} for student #{email}" unless advisor_user

    user = seed_user.call(email: email, name: name, role: :student)
    profile = user.student_profile || Student.new(student_id: user.id)
    profile.assign_attributes(track: track, advisor: advisor_user.advisor_profile, program_year: program_year)
    # Bypass validations for seed data; first-login flow will collect required fields
    profile.save!(validate: false)

    { profile: profile, pending: pending, multi_semester: multi_semester }
  end

  students = students_with_metadata.map { |entry| entry[:profile] }
  pending_student_ids = students_with_metadata.select { |entry| entry[:pending] }.map { |entry| entry[:profile].student_id }
  multi_semester_student_ids = students_with_metadata.select { |entry| entry[:multi_semester] }.map { |entry| entry[:profile].student_id }

  high_performer_emails = %w[
    nova.mitchell25@tamu.edu
    emery.walsh24@tamu.edu
    kiara.hughes25@tamu.edu
  ]
  high_performers = students.select { |student| high_performer_emails.include?(student.user.email) }
  high_performer_ids = high_performers.map(&:student_id)
end

puts "• Loading program survey templates"
survey_template_path = Rails.root.join("db", "data", "program_surveys.yml")
unless File.exist?(survey_template_path)
  raise "Survey template data file not found: #{survey_template_path}. Please ensure the survey definitions are available."
end

template_data = YAML.safe_load_file(survey_template_path, aliases: true)
survey_templates = Array(template_data.fetch("surveys"))

preferred_seed_current_semester = "Fall 2025"
semester_names = survey_templates.map do |definition|
  definition.fetch("program_semester").to_s.strip.presence
end.compact.uniq
if semester_names.blank?
  semester_names = [Time.zone.now.strftime("%B %Y")]
end

existing_current_semester = ProgramSemester.current_name.to_s.strip.presence
# Seed behavior: in non-production environments, prefer the newest semester so
# newly created accounts get the newest surveys assigned automatically.
target_current_semester = if Rails.env.production? && !seed_demo_data
  existing_current_semester ||
    semester_names.find { |name| name.casecmp?(preferred_seed_current_semester) } ||
    semester_names.last
else
  semester_names.find { |name| name.casecmp?("Spring 2026") } ||
    semester_names.last ||
    existing_current_semester
end

target_current_semester ||= semester_names.first

unless semester_names.include?(target_current_semester)
  semester_names << target_current_semester
  semester_names.uniq!
end

puts "• Syncing program semesters"
ProgramSemester.transaction do
  semester_names.each do |name|
    ProgramSemester.find_or_create_by!(name: name)
  end

  ProgramSemester.where.not(name: target_current_semester).update_all(current: false)
  ProgramSemester.find_or_create_by!(name: target_current_semester).update!(current: true)
end

if ActiveRecord::Base.connection.data_source_exists?("competency_target_levels")
  defaults_path = Rails.root.join("db", "data", "default_target_levels.yml")
  if File.exist?(defaults_path)
    puts "• Seeding default competency target levels"

    defaults = YAML.safe_load_file(defaults_path)
    semesters_to_seed = Array(defaults["semesters"]).map { |name| name.to_s.strip }.reject(&:blank?)
    program_years_to_seed = Array(defaults["program_years"]).map { |val| val.to_i }.uniq
    track_defaults = defaults["tracks"].is_a?(Hash) ? defaults["tracks"] : {}

    competency_titles = Reports::DataAggregator::COMPETENCY_TITLES
    now = Time.current
    rows = []

    semesters_to_seed.each do |semester_name|
      program_semester = ProgramSemester.find_or_create_by!(name: semester_name)

      track_defaults.each do |track_name, track_config|
        levels = Array(track_config.is_a?(Hash) ? track_config["levels"] : nil).map(&:to_i)
        if levels.size != competency_titles.size
          warn "• Skipping target levels for #{track_name} (#{semester_name}): expected #{competency_titles.size} levels, got #{levels.size}"
          next
        end

        program_years_to_seed.each do |program_year|
          competency_titles.each_with_index do |title, idx|
            rows << {
              program_semester_id: program_semester.id,
              track: track_name,
              program_year: program_year,
              competency_title: title,
              target_level: levels[idx],
              created_at: now,
              updated_at: now
            }
          end
        end
      end
    end

    if rows.any?
      CompetencyTargetLevel.upsert_all(rows, unique_by: :index_competency_targets_unique)
    end
  end
end

answer_options_for = lambda do |options|
  return nil if options.blank?

  normalized = Array(options).filter_map do |entry|
    case entry
    when String
      entry.to_s.strip.presence
    when Array
      next if entry.empty?

      label = entry[0].to_s.strip
      value = entry[1].to_s.strip
      next if label.blank? || value.blank?

      [label, value]
    when Hash
      label = (entry["label"] || entry[:label]).to_s.strip
      value = (entry["value"] || entry[:value] || label).to_s.strip
      next if label.blank? || value.blank?

      { "label" => label, "value" => value }
    else
      entry.to_s.strip.presence
    end
  end

  normalized.to_json
end

created_surveys = []
survey_due_dates = nil

legend_supported = ActiveRecord::Base.connection.data_source_exists?("survey_legends")
question_target_level_supported = ActiveRecord::Base.connection.column_exists?(:questions, :program_target_level)
sub_questions_supported = ActiveRecord::Base.connection.column_exists?(:questions, :parent_question_id) &&
                          ActiveRecord::Base.connection.column_exists?(:questions, :sub_question_order)

survey_templates.each do |definition|
  title = definition.fetch("title")
  semester = definition.fetch("program_semester").to_s.strip
  puts "   • Ensuring survey: #{title} (#{semester})"

  program_semester = ProgramSemester.find_or_create_by!(name: semester)

  Survey.transaction do
    survey = Survey.find_or_initialize_by(title: title, program_semester: program_semester)
    survey.creator ||= admin_users.first || User.admins.first
    survey.description = definition["description"]
    survey.is_active = definition.fetch("is_active", true)

    if legend_supported
      legend_definition = definition["legend"].presence
      if legend_definition.present?
        legend_record = survey.legend || survey.build_legend
        legend_record.title = legend_definition["title"].to_s.strip.presence
        legend_record.body = legend_definition.fetch("body", "").to_s
      else
        survey.legend&.mark_for_destruction
      end
    end

    if survey.persisted?
      stale_category_ids = survey.categories.ids
      stale_question_ids = survey.questions.ids

      if stale_category_ids.any?
        survey.feedbacks.where(category_id: stale_category_ids).delete_all
      end

      if stale_question_ids.any?
        survey.feedbacks.where(question_id: stale_question_ids).delete_all
      end

      survey.categories.destroy_all
      survey.categories.reset
    else
      survey.categories.reset
    end

    sections_supported = SurveySection.table_exists?
    if sections_supported
      survey.sections.destroy_all if survey.persisted?
      survey.sections.reset
    end

    question_feedback_supported = Question.column_names.include?("has_feedback")

    categories = Array(definition.fetch("categories", []))
    section_assignments = sections_supported ? {} : nil
    categories.each do |category_definition|
      category = survey.categories.build(
        name: category_definition.fetch("name"),
        description: category_definition["description"]
      )

      section_definition = category_definition["section"]
      section_title = section_definition&.fetch("title", nil).to_s.strip
      is_mha_competency_section = section_title.present? && section_title.casecmp?(SurveySection::MHA_COMPETENCY_SECTION_TITLE)
      if sections_supported && section_definition.present?
        if section_title.present?
          section_assignments[category] = {
            title: section_title,
            description: section_definition["description"],
            position: section_definition["position"]
          }
        end
      end

      Array(category_definition.fetch("questions", [])).each do |question_definition|
        tooltip_value = question_definition["tooltip"].to_s.strip
        if tooltip_value.blank? && is_mha_competency_section && question_definition["type"].to_s == "multiple_choice"
          tooltip_value = question_definition["description"].to_s.strip
        end

        build_attrs = {
          question_text: question_definition.fetch("text"),
          description: question_definition["description"],
          tooltip_text: tooltip_value.presence,
          question_order: question_definition.fetch("order"),
          question_type: question_definition.fetch("type"),
          is_required: question_definition.fetch("required", false),
          has_evidence_field: question_definition.fetch("has_evidence_field", false),
          answer_options: answer_options_for.call(question_definition["options"])
        }

        if question_feedback_supported
          build_attrs[:has_feedback] = question_definition.fetch("has_feedback", is_mha_competency_section)
        end

        if question_target_level_supported && is_mha_competency_section && %w[multiple_choice dropdown].include?(question_definition["type"].to_s)
          raw_target_level = question_definition["target_level"].presence || question_definition["program_target_level"].presence || 3
          build_attrs[:program_target_level] = raw_target_level.to_i
        end

        parent_question = category.questions.build(build_attrs)

        if sub_questions_supported
          Array(question_definition["sub_questions"]).each do |sub_definition|
          sub_tooltip_value = sub_definition["tooltip"].to_s.strip
          if sub_tooltip_value.blank? && is_mha_competency_section && sub_definition["type"].to_s == "multiple_choice"
            sub_tooltip_value = sub_definition["description"].to_s.strip
          end

          sub_attrs = {
            question_text: sub_definition.fetch("text"),
            description: sub_definition["description"],
            tooltip_text: sub_tooltip_value.presence,
            question_order: parent_question.question_order,
            sub_question_order: sub_definition.fetch("order", 0),
            question_type: sub_definition.fetch("type"),
            is_required: sub_definition.fetch("required", false),
            has_evidence_field: sub_definition.fetch("has_evidence_field", false),
            answer_options: answer_options_for.call(sub_definition["options"]),
            parent_question: parent_question
          }

          if question_feedback_supported
            sub_attrs[:has_feedback] = sub_definition.fetch("has_feedback", false)
          end

          if question_target_level_supported && is_mha_competency_section && %w[multiple_choice dropdown].include?(sub_definition["type"].to_s)
            raw_target_level = sub_definition["target_level"].presence || sub_definition["program_target_level"].presence || 3
            sub_attrs[:program_target_level] = raw_target_level.to_i
          end

          category.questions.build(sub_attrs)
          end
        end
      end
    end

    survey.save!

    if sub_questions_supported
      # When building nested questions in-memory, sub-questions may be saved before the
      # parent question has an ID, leaving parent_question_id unset. Repair those links
      # after the survey save so sub-questions are correctly attached.
      survey.categories.each do |category|
        category.questions.each do |question|
          parent = question.parent_question
          next unless parent
          next if question.parent_question_id.present?
          next unless parent.id

          question.update!(parent_question_id: parent.id)
        end
      end
    end

    if sections_supported && section_assignments.present?
      section_records = {}
      ordered_keys = []

      section_assignments.each_value do |attrs|
        title = attrs[:title]
        next if title.blank?
        next if section_records.key?(title)

        ordered_keys << title
        section_records[title] = survey.sections.create!(
          title: title,
          description: attrs[:description],
          position: attrs[:position].presence || ordered_keys.size
        )
      end

      section_assignments.each do |category, attrs|
        section = section_records[attrs[:title]]
        next unless section

        category.update!(section: section)
      end
    end

    tracks = Array(definition.fetch("tracks", [])).map(&:to_s)
    survey.assign_tracks!(tracks)

    raw_due_date = definition["due_date"].to_s.strip
    if raw_due_date.present?
      begin
        parsed_due_date = Time.zone.parse(raw_due_date)
        survey.due_date = parsed_due_date.end_of_day if parsed_due_date
      rescue StandardError
        # Ignore invalid due dates; we will fall back to default assignment logic.
      end
    end

    survey.save! if survey.changed?

    created_surveys << survey
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

choice_values_for = lambda do |question|
  raw = question.answer_options.presence || "[]"
  parsed = JSON.parse(raw)
  Array(parsed).filter_map do |entry|
    case entry
    when String
      entry.to_s.strip.presence
    when Hash
      (entry["value"] || entry[:value] || entry["label"] || entry[:label]).to_s.strip.presence
    when Array
      next if entry.empty?

      (entry[1] || entry[0]).to_s.strip.presence
    else
      entry.to_s.strip.presence
    end
  end.uniq
rescue JSON::ParserError
  []
end

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
  pending_student = pending_student_ids.include?(student.student_id)
  program_year_value = student.program_year.to_i

  surveys_to_seed = created_surveys.select do |survey|
    survey.program_semester&.name.to_s.strip.casecmp?(target_current_semester.to_s.strip) &&
      survey.track_list.any? { |track| track.to_s.strip.casecmp?(track_value.to_s.strip) }
  end
  if multi_semester_student_ids.include?(student.student_id) || program_year_value == 2
    multi_semesters = ["Spring 2025", "Fall 2025", "Spring 2026"].freeze
    extra_surveys = created_surveys.select do |survey|
      multi_semesters.include?(survey.program_semester.name.to_s.strip) &&
        survey.track_list.any? { |track| track.to_s.strip.casecmp?(track_value.to_s.strip) }
    end
    surveys_to_seed = (surveys_to_seed + extra_surveys).uniq
  end

  surveys_to_seed.each do |survey|
    latest_response_timestamp = nil

    unless pending_student
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
                           options = choice_values_for.call(question)

                           if is_competency_question
                             rating_value = competency_rating_value.call(high_performer: high_performer)
                             options.include?(rating_value) ? rating_value : (options.sample(random: response_rng).presence || rating_value || "3")
                           else
                             preferred = high_performer ? "Yes" : nil
                             selection = options.sample(random: response_rng).presence
                             fallback = preferred && options.include?(preferred) ? preferred : selection
                             fallback.presence || preferred || options.first || "Yes"
                           end
                         when "dropdown"
                           options = choice_values_for.call(question)

                           if is_competency_question
                             rating_value = competency_rating_value.call(high_performer: high_performer)
                             options.include?(rating_value) ? rating_value : (options.sample(random: response_rng).presence || rating_value || "3")
                           else
                             options.sample(random: response_rng).presence || options.first
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
        latest_response_timestamp = [ latest_response_timestamp, timestamp ].compact.max

        record.response_value = response_value
        record.save!
      end

      puts "   • Prepared #{survey.questions.count} questions for #{student.user.name} (#{track_value})"
      puts "     ↳ High performer calibration applied" if high_performer_ids.include?(student.student_id)
      puts "     ↳ Track auto-assign will create survey tasks on next profile update"

      # Seed completion history for most Year-1 students on the Spring 2026 survey.
      # This helps exercise UI states that depend on completed assignments.
      if survey.program_semester&.name.to_s.strip.casecmp?("Spring 2026") && program_year_value == 1
        incomplete_seed_email = "zoe.elliott24@tamu.edu"
        completion_timestamp = latest_response_timestamp || Time.current

        assignment = SurveyAssignment.find_or_create_by!(student_id: student.student_id, survey_id: survey.id) do |record|
          record.advisor_id = student.advisor_id
          record.assigned_at = completion_timestamp
          record.due_date = survey.due_date if survey.respond_to?(:due_date)
        end

        assignment.update!(advisor_id: student.advisor_id) if assignment.advisor_id.blank? && student.advisor_id.present?
        assignment.update!(due_date: survey.due_date) if assignment.due_date.blank? && survey.respond_to?(:due_date) && survey.due_date.present?
        assignment.update!(completed_at: nil) if student.user.email.to_s.downcase == incomplete_seed_email

        unless student.user.email.to_s.downcase == incomplete_seed_email
          assignment.mark_completed!(completion_timestamp)

          SurveyResponseVersion.capture_current!(
            student: student,
            survey: survey,
            assignment: assignment,
            actor_user: student.user,
            event: :submitted,
            skip_if_unchanged: true
          )
        end
      end

      # Seed Year-2 students with multi-semester completions so confidential
      # notes history and version navigation have realistic data.
      if program_year_value == 2
        completion_semesters = ["Spring 2025", "Fall 2025", "Spring 2026"].freeze
        if completion_semesters.include?(survey.program_semester&.name.to_s.strip)
          completion_timestamp = latest_response_timestamp || Time.current

          assignment = SurveyAssignment.find_or_create_by!(student_id: student.student_id, survey_id: survey.id) do |record|
            record.advisor_id = student.advisor_id
            record.assigned_at = completion_timestamp
            record.due_date = survey.due_date if survey.respond_to?(:due_date)
          end

          assignment.update!(advisor_id: student.advisor_id) if assignment.advisor_id.blank? && student.advisor_id.present?
          assignment.update!(due_date: survey.due_date) if assignment.due_date.blank? && survey.respond_to?(:due_date) && survey.due_date.present?
          assignment.mark_completed!(completion_timestamp)

          SurveyResponseVersion.capture_current!(
            student: student,
            survey: survey,
            assignment: assignment,
            actor_user: student.user,
            event: :submitted,
            skip_if_unchanged: true
          )
        end
      end
    else
      puts "   • Assigned #{survey.title} to #{student.user.name} (#{track_value}) — awaiting completion"
    end

    # Survey assignments are intentionally not created here.
    # We rely on SurveyAssignments::AutoAssigner (triggered by student profile
    # updates) to assign the newest surveys so assignment behavior is exercised
    # consistently in dev/test.
  end
end

puts "   • Generated sample ratings for #{StudentQuestion.count} question responses"

puts "🎉 Seed data finished!"

ensure
  $stdout = _seed_original_stdout if _seed_silence_stdout
end
