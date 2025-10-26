# db/seeds.rb
require "json"
require "yaml"

puts "\n== Seeding Health sample data =="

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
  { email: "rainsuds@tamu.edu", name: "System Administrator" },
  { email: "anthuan374@tamu.edu", name: "System Administrator" },
  { email: "faqiang_mei@tamu.edu", name: "System Administrator" },
  { email: "jonah.belew@tamu.edu", name: "System Administrator" },
  { email: "cstebbins@tamu.edu", name: "System Administrator" },
  { email: "kum@tamu.edu", name: "System Administrator" },
  { email: "ruoqiwei@tamu.edu", name: "System Administrator" }
]

admin_users = admin_accounts.map do |attrs|
  seed_user.call(email: attrs[:email], name: attrs[:name], role: :admin)
end

puts "• Creating advisor accounts"
advisor_users = [
  seed_user.call(email: "anthuan374@tamu.edu", name: "Marcos Morales", role: :advisor),
  seed_user.call(email: "jonah.belew@tamu.edu", name: "Jonah Belew", role: :advisor)
]

advisors = advisor_users.map(&:advisor_profile)

puts "• Creating sample students"
students_seed = [
  { email: "faqiang_mei@tamu.edu", name: "Faqiang Mei", track: "Residential", advisor: advisors.first },
  { email: "jonah.belew@tamu.edu", name: "J Belew", track: "Residential", advisor: advisors.first },
  { email: "rainsuds@tamu.edu", name: "Tee Li", track: "Executive", advisor: advisors.last },
  { email: "anthuan374@tamu.edu", name: "Anthuan", track: "Residential", advisor: advisors.last },
  { email: "meif7749@tamu.edu", name: "Executive Test", track: "Executive", advisor: advisors.last }
]

students = students_seed.map do |attrs|
  user = seed_user.call(email: attrs[:email], name: attrs[:name], role: :student)
  profile = user.student_profile || Student.new(student_id: user.id)
  profile.assign_attributes(track: attrs[:track], advisor: attrs[:advisor])
  # Bypass validations for seed data; first-login flow will collect required fields
  profile.save!(validate: false)
  profile
end

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
      surveys_by_track[track] << survey
    end
  end
end

puts "• Assigning surveys to each student"
students.each do |student|
  track_value = student.track.to_s
  next if track_value.blank?

  Array(surveys_by_track[track_value]).each do |survey|
    survey.questions.order(:question_order).each do |question|
      StudentQuestion.find_or_create_by!(student_id: student.student_id, question_id: question.id) do |record|
        record.advisor_id = student.advisor&.advisor_id
      end
    end

    Notification.find_or_create_by!(
      notifiable: student,
      title: "Survey ready: #{survey.title}"
    ) do |notification|
      notification.message = "#{survey.title} has been assigned to you for #{survey.semester}."
    end

    puts "   • Prepared #{survey.questions.count} questions for #{student.user.name} (#{track_value})"
  end
end

puts "🎉 Seed data finished!"
