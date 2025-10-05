# db/seeds.rb
require "json"
require "securerandom"

puts "\n== Seeding Health sample data =="

# --- Clean up existing data ---
puts "🧹 Deleting all existing records..."
[SurveyResponse, QuestionResponse, Feedback, Question, Category, Survey, Student, User].each do |model|
  begin
    model.delete_all
    puts "🗑️  Cleared #{model.name}"
  rescue NameError
    puts "⚠️  Skipping #{model.name} (not defined)"
  end
end

# --- Create Users ---
puts "• Creating core users"

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

advisors = []
advisor_profiles = advisors.map(&:advisor_profile)

students_seed = [
  { email: "faqiangmei@gmail.com", name: "Faqiang Mei", net_id: "fmei", track: "Residential", advisor: advisor_profiles.first },
  { email: "j.belew714@gmail.com", name: "J Belew", net_id: "jbelew714", track: "Residential", advisor: advisor_profiles.first },
  { email: "rainsuds123@gmail.com", name: "Tee Li", net_id: "rainsuds123", track: "Executive", advisor: advisor_profiles.last },
  { email: "anthuan374@gmail.com", name: "Anthuan", net_id: "anthuan374", track: "Residential", advisor: advisor_profiles.last },
  { email: "meif7749@gmail.com", name: "Executive Test", net_id: "meif7749", track: "Executive", advisor: advisor_profiles.last }
]

puts "• Creating student users..."
students_seed.each do |attrs|
  user = User.find_or_create_by!(email: attrs[:email]) do |u|
    u.name = attrs[:name]
    u.role = :student
  end
  student = Student.find_or_create_by!(student_id: user.id)
  student.update!(track: attrs[:track], advisor: attrs[:advisor])
end

# --- Surveys ---
puts "• Creating surveys, categories, and questions"

# -------------------- Executive Survey --------------------
puts "📋 Creating Executive Survey..."
exec_survey = Survey.find_or_create_by!(title: "Executive Survey", semester: "Fall 2025")
puts "Created Executive Survey: #{exec_survey.id}"

exec_categories = [
  {
    name: "Semester",
    description: "Semester Activity Information",
    questions: [
      { order: 1, question: "Which student organizations are you currently a member of?", type: "multiple_choice", options: ["AFHL", "AAHL", "HFA", "IHI", "MGMA", "AC3"] },
      { order: 2, question: "Other Organization - please specify the name", type: "short_answer" },
      { order: 3, question: "Did you participate in any professional meetings?", type: "multiple_choice", options: ["Yes", "No"] },
      { order: 4, question: "If yes, please provide the meeting name, date, and location", type: "short_answer" },
      { order: 5, question: "If no, why not?", type: "short_answer" },
      { order: 6, question: "Did you compete in a Case Competition?", type: "multiple_choice", options: ["Yes", "No"] },
      { order: 7, question: "If yes, name and date", type: "short_answer" },
      { order: 8, question: "If no, why not?", type: "short_answer" },
      { order: 9, question: "Did you engage in a community service activity?", type: "multiple_choice", options: ["Yes", "No"] },
      { order: 10, question: "If yes, provide the activity name, date, and location", type: "short_answer" },
      { order: 11, question: "If no, why not?", type: "short_answer" }
    ]
  },
  {
    name: "Mentor Relationships (RMHA Only)",
    description: "Mentorship Information",
    questions: [
      { order: 1, question: "Did you meet with your alumni mentor?", type: "multiple_choice", options: ["Yes", "No"] },
      { order: 2, question: "Summarize your discussions", type: "short_answer" },
      { order: 3, question: "If not, why not?", type: "short_answer" },
      { order: 4, question: "Did you meet with your student mentor/mentee?", type: "multiple_choice", options: ["Yes", "No"] },
      { order: 5, question: "Summarize your meetings", type: "short_answer" },
      { order: 6, question: "If not, why not?", type: "short_answer" }
    ]
  },
  {
    name: "Volunteering/Service",
    description: "Volunteer Work Information",
    questions: [
      { order: 1, question: "Any volunteer service?", type: "multiple_choice", options: ["Yes", "No"] },
      { order: 2, question: "If yes, please describe.", type: "short_answer" },
      { order: 3, question: "If no, why not?", type: "short_answer" }
    ]
  },
  {
    name: "Health Care Environment and Community",
    description: "Relation between health care operations and community organizations and policies",
    questions: [
      { order: 1, question: "Public and Population Health Assessment", type: "short_answer" },
      { order: 2, question: "Delivery, Organization, and Financing of Health Services", type: "short_answer" },
      { order: 3, question: "Policy Analysis", type: "short_answer" },
      { order: 4, question: "Legal and Ethical Bases for Health Services", type: "short_answer" }
    ]
  },
  {
    name: "Leadership Skills",
    description: "Motivation and empowerment of organizational resources",
    questions: [
      { order: 1, question: "Ethics, Accountability, and Self-Assessment", type: "short_answer" },
      { order: 2, question: "Organizational Dynamics", type: "short_answer" },
      { order: 3, question: "Problem Solving, Decision Making, and Critical Thinking", type: "short_answer" },
      { order: 4, question: "Team Building and Collaboration", type: "short_answer" }
    ]
  },
  {
    name: "Management Skills",
    description: "Control and organization of health services delivery",
    questions: [
      { order: 1, question: "Strategic Planning", type: "short_answer" },
      { order: 2, question: "Business Planning", type: "short_answer" },
      { order: 3, question: "Communication", type: "short_answer" },
      { order: 4, question: "Financial Management", type: "short_answer" },
      { order: 5, question: "Performance Improvement", type: "short_answer" },
      { order: 6, question: "Project Management", type: "short_answer" }
    ]
  },
  {
    name: "Analytic and Technical Skills",
    description: "Successful accomplishment of tasks in health services delivery",
    questions: [
      { order: 1, question: "Systems Thinking", type: "short_answer" },
      { order: 2, question: "Data Analysis and Information Management", type: "short_answer" },
      { order: 3, question: "Quantitative Methods for Health Services Delivery", type: "short_answer" }
    ]
  }
]

exec_categories.each do |cat|
  c = Category.find_or_create_by!(survey_id: exec_survey.id, name: cat[:name], description: cat[:description])
  puts "  🗂️  Created Category: #{c.id} - #{c.name}"
  cat[:questions].each do |q|
    qq = Question.find_or_create_by!(category_id: c.id, question_order: q[:order], question: q[:question]) do |qq|
      qq.question_type = q[:type]
      qq.answer_options = q[:options]&.to_json
    end
    puts "    ✏️  Created Question: #{qq.id} - #{qq.question}"
  end
end

# -------------------- Residential Survey --------------------
puts "📋 Creating Residential Survey..."
res_survey = Survey.find_or_create_by!(title: "Residential Survey", semester: "Fall 2025")
puts "Created Residential Survey: #{res_survey.id}"

res_categories = [
  {
    name: "Health Care Environment and Community",
    description: "Relationship between health care operations and their communities",
    questions: [
      { order: 1, question: "Public and Population Health Assessment", type: "short_answer" },
      { order: 2, question: "Delivery, Organization, and Financing of Health Services", type: "short_answer" },
      { order: 3, question: "Policy Analysis", type: "short_answer" },
      { order: 4, question: "Legal and Ethical Bases for Health Services", type: "short_answer" }
    ]
  },
  {
    name: "Leadership Skills",
    description: "Motivation and empowerment of organizational resources",
    questions: [
      { order: 1, question: "Ethics, Accountability, and Self-Assessment", type: "short_answer" },
      { order: 2, question: "Organizational Dynamics", type: "short_answer" },
      { order: 3, question: "Problem Solving, Decision Making, and Critical Thinking", type: "short_answer" },
      { order: 4, question: "Team Building and Collaboration", type: "short_answer" }
    ]
  },
  {
    name: "Management Skills",
    description: "Control and organization of health services delivery",
    questions: [
      { order: 1, question: "Strategic Planning", type: "short_answer" },
      { order: 2, question: "Business Planning", type: "short_answer" },
      { order: 3, question: "Communication", type: "short_answer" },
      { order: 4, question: "Financial Management", type: "short_answer" },
      { order: 5, question: "Performance Improvement", type: "short_answer" },
      { order: 6, question: "Project Management", type: "short_answer" }
    ]
  },
  {
    name: "Analytic and Technical Skills",
    description: "Successful accomplishment of tasks in health services delivery",
    questions: [
      { order: 1, question: "Systems Thinking", type: "short_answer" },
      { order: 2, question: "Data Analysis and Information Management", type: "short_answer" },
      { order: 3, question: "Quantitative Methods for Health Services Delivery", type: "short_answer" }
    ]
  }
]

res_categories.each do |cat|
  c = Category.find_or_create_by!(survey_id: res_survey.id, name: cat[:name], description: cat[:description])
  puts "  🗂️  Created Category: #{c.id} - #{c.name}"
  cat[:questions].each do |q|
    qq = Question.find_or_create_by!(category_id: c.id, question_order: q[:order], question: q[:question]) do |qq|
      qq.question_type = q[:type]
      qq.answer_options = q[:options]&.to_json
    end
    puts "    ✏️  Created Question: #{qq.id} - #{qq.question}"
  end
end

# --- Link survey responses ---
puts "• Linking survey responses to questions for each student..."
Student.includes(:user).find_each do |student|
  track_value = student.track.to_s
  puts "👀 Student: #{student.user.name} | track=#{track_value.inspect}"

  next if track_value.blank?

  survey = case track_value.downcase
           when "executive" then Survey.find_by("LOWER(title) = ?", "executive survey")
           when "residential" then Survey.find_by("LOWER(title) = ?", "residential survey")
           end
  next unless survey

  sr = SurveyResponse.find_or_create_by!(student_id: student.id, survey_id: survey.id) do |resp|
    resp.status = SurveyResponse.statuses[:not_started]
    resp.advisor_id = student.advisor_id
  end
  puts "✅ Created SurveyResponse for #{student.user.name} (#{student.track}) → #{survey.title}"

  survey.questions.each do |q|
    QuestionResponse.find_or_create_by!(surveyresponse_id: sr.id, question_id: q.id)
  end
  puts "   ↳ Linked #{survey.questions.count} questions"
end

puts "🎉 Done! SurveyResponses and QuestionResponses linked successfully!"
