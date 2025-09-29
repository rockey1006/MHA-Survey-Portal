# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create admin user
Admin.find_or_create_by(email: 'rainsuds@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end

Admin.find_or_create_by(email: 'jcwtexasanm@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end

Admin.find_or_create_by(email: 'anthuan374@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end

Admin.find_or_create_by(email: 'faqiang_mei@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end

Admin.find_or_create_by(email: 'jonah.belew@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end

Admin.find_or_create_by(email: 'cstebbins@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end

Admin.find_or_create_by(email: 'kum@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end

Admin.find_or_create_by(email: 'ruoqiwei@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end


# ---------------------------------------------------------------------------
# Default sample survey + competencies + questions (idempotent)
# ---------------------------------------------------------------------------
survey1 = Survey.find_or_create_by!(title: "Default Sample Survey", semester: "Fall 2025")
survey2 = Survey.find_or_create_by!(title: "Career Goals Survey", semester: "Fall 2025")

# Survey 1
comp_prof1 = Competency.find_or_create_by!(survey_id: survey1.id, name: "Professional Skills")
comp_tech1 = Competency.find_or_create_by!(survey_id: survey1.id, name: "Technical Skills")

Question.find_or_create_by!(competency_id: comp_prof1.id, question_order: 1, question: "I communicate effectively with my peers.") do |q|
  q.question_type = 'radio'
  q.answer_options = [ 'Strongly disagree', 'Disagree', 'Neutral', 'Agree', 'Strongly agree' ].to_json
end
Question.find_or_create_by!(competency_id: comp_prof1.id, question_order: 2, question: "Describe a recent teamwork experience.") do |q|
  q.question_type = 'text'
  q.answer_options = nil
end
Question.find_or_create_by!(competency_id: comp_tech1.id, question_order: 1, question: "Rate your proficiency in Ruby on Rails.") do |q|
  q.question_type = 'select'
  q.answer_options = [ 'Beginner', 'Intermediate', 'Advanced' ].to_json
end
Question.find_or_create_by!(competency_id: comp_tech1.id, question_order: 2, question: "Which frameworks have you used recently?") do |q|
  q.question_type = 'text'
  q.answer_options = nil
end

# Survey 2
comp_goal = Competency.find_or_create_by!(survey_id: survey2.id, name: "Career Planning")
comp_growth = Competency.find_or_create_by!(survey_id: survey2.id, name: "Personal Growth")

Question.find_or_create_by!(competency_id: comp_goal.id, question_order: 1, question: "What is your desired career path after graduation?") do |q|
  q.question_type = 'text'
  q.answer_options = nil
end
Question.find_or_create_by!(competency_id: comp_goal.id, question_order: 2, question: "Which industries are you most interested in?") do |q|
  q.question_type = 'checkbox'
  q.answer_options = [ 'Healthcare', 'Finance', 'Technology', 'Education' ].to_json
end
Question.find_or_create_by!(competency_id: comp_growth.id, question_order: 1, question: "What skills do you want to develop?") do |q|
  q.question_type = 'text'
  q.answer_options = nil
end
Question.find_or_create_by!(competency_id: comp_growth.id, question_order: 2, question: "Who inspires you in your career journey?") do |q|
  q.question_type = 'text'
  q.answer_options = nil
end

puts "Ensured default surveys and questions exist (survey1 id=#{survey1.id}, survey2 id=#{survey2.id})"


# Ensure only these four student accounts exist for local login/testing
students_seed = [
  { email: 'faqiangmei@gmail.com', name: 'Faqiang Mei', net_id: 'fmei' },
  { email: 'j.belew714@gmail.com', name: 'J Belew', net_id: 'jbelew714' },
  { email: 'rainsuds123@gmail.com', name: 'Rainsuds', net_id: 'rainsuds123' },
  { email: 'anthuan374@gmail.com', name: 'Anthuan', net_id: 'anthuan374' }
]

Student.where.not(email: students_seed.map { |s| s[:email] }).destroy_all

students_seed.each do |student|
  Student.find_or_create_by!(email: student[:email]) do |s|
    s.name = student[:name]
    s.net_id = student[:net_id]
    s.track = 'residential'
    puts "Created student: #{s.email}"
  end
end
