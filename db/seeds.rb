# db/seeds.rb
require "json"
require "yaml"

puts "\n== Seeding Health sample data =="

MODELS_TO_CLEAR = [
  Notification,
  StudentQuestion,
  SurveyQuestion,
  CategoryQuestion,
  Feedback,
  Question,
  Category,
  Survey,
  Student,
  Advisor,
  Admin,
  User
].freeze

puts "🧹 Deleting existing records..."
MODELS_TO_CLEAR.each do |model|
  model.delete_all
  puts "   • cleared #{model.name}"
end

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
  seed_user.call(email: "advisor.one@tamu.edu", name: "Advisor One", role: :advisor),
  seed_user.call(email: "advisor.two@tamu.edu", name: "Advisor Two", role: :advisor)
]

advisors = advisor_users.map(&:advisor_profile)

puts "• Creating sample students"
students_seed = [
  { email: "faqiangmei@tamu.edu", name: "Faqiang Mei", track: "Residential", advisor: advisors.first },
  { email: "j.belew714@tamu.edu", name: "J Belew", track: "Residential", advisor: advisors.first },
  { email: "rainsuds123@tamu.edu", name: "Tee Li", track: "Executive", advisor: advisors.last },
  { email: "anthuan374@tamu.edu", name: "Anthuan", track: "Residential", advisor: advisors.last },
  { email: "meif7749@tamu.edu", name: "Executive Test", track: "Executive", advisor: advisors.last }
]

students = students_seed.map do |attrs|
  user = seed_user.call(email: attrs[:email], name: attrs[:name], role: :student)
  profile = user.student_profile || Student.new(student_id: user.id)
  profile.assign_attributes(track: attrs[:track], advisor: attrs[:advisor])
  profile.save!
  profile
end

puts "• Loading competency model"
competency_source_path = Rails.root.join("db", "data", "mha_competencies.yml")
unless File.exist?(competency_source_path)
  raise "Competency data file not found: #{competency_source_path}. Please ensure the official model is available."
end

competency_data = YAML.load_file(competency_source_path)
domains = competency_data.fetch("domains")

survey = Survey.create!(title: "Competency Self-Assessment Survey", semester: "Fall 2025")
puts "   • Survey: #{survey.title}"

likert_options = %w[1 2 3 4 5]
question_counter = 0

domains.each do |domain|
  category = Category.create!(name: domain.fetch("name"), description: domain["description"])
  puts "      ▸ Domain: #{category.name}"

  competencies = domain.fetch("competencies", [])
  competencies.each do |competency|
    question_counter += 1
    question = Question.create!(
      question: competency.fetch("prompt"),
      question_order: question_counter,
      question_type: Question.question_types[:scale],
      required: true,
      answer_options: likert_options.to_json
    )

    SurveyQuestion.create!(survey: survey, question: question)
    CategoryQuestion.create!(
      category: category,
      question: question,
      display_label: competency["title"] || competency["prompt"]
    )

    puts "        ↳ Competency ##{question_counter}: #{competency["title"] || competency["prompt"]}"
  end

  question_counter += 1
  evidence_prompt = "Provide evidence or reflection for #{domain.fetch("name")}".freeze
  evidence_question = Question.create!(
    question: evidence_prompt,
    question_order: question_counter,
    question_type: Question.question_types[:evidence],
    required: false
  )

  SurveyQuestion.create!(survey: survey, question: evidence_question)
  CategoryQuestion.create!(
    category: category,
    question: evidence_question,
    display_label: "Evidence for #{domain.fetch("name")}",
    description: "Attach a Google Drive link or describe supporting evidence for this competency domain."
  )

  puts "        ↳ Evidence field added for #{domain.fetch("name")}" 
end

puts "• Assigning competency questions to each student"
students.each do |student|
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

  puts "   • Prepared #{survey.questions.count} questions for #{student.user.name}"
end

puts "🎉 Seed data finished!"
