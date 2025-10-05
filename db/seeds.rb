require "date"
require "json"
require "securerandom"

puts "\n== Seeding Health sample data =="

ActiveRecord::Base.transaction do
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

  puts "• Creating core users"

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

  advisors = [
  ]

  advisor_profiles = advisors.map(&:advisor_profile)

  students_seed = [
    { email: "faqiangmei@gmail.com", name: "Faqiang Mei", net_id: "fmei", track: :residential, advisor: advisor_profiles.first },
    { email: "j.belew714@gmail.com", name: "J Belew", net_id: "jbelew714", track: :residential, advisor: advisor_profiles.first },
    { email: "rainsuds123@gmail.com", name: "Tee Li", net_id: "rainsuds123", track: :executive, advisor: advisor_profiles.last },
    { email: "anthuan374@gmail.com", name: "Anthuan", net_id: "anthuan374", track: :residential, advisor: advisor_profiles.last }
  ]

  allowed_student_emails = students_seed.map { |attrs| attrs[:email] }

  User.students.where.not(email: allowed_student_emails).find_each do |user|
    user.destroy!
  end

  student_profiles = students_seed.map.with_index(1) do |attrs, index|
    user = seed_user.call(email: attrs[:email], name: attrs[:name], role: :student)
    profile = user.student_profile
    profile.update!(
      uin: attrs[:net_id],
      track: attrs[:track],
      advisor: attrs[:advisor]
    )
    profile
  end

  puts "• Creating surveys, categories, and questions"

  survey_blueprint = {
    title: "MHA Professional Development Survey",
    semester: "Fall 2025",
    categories: [
      {
        name: "Leadership & Communication",
        description: "Self-assessment of leadership presence and communication skills.",
        questions: [
          {
            order: 1,
            text: "Rate your confidence leading cross-functional teams.",
            type: :scale,
            options: ["1", "2", "3", "4", "5"],
            sample_answer: "4"
          },
          {
            order: 2,
            text: "Describe a recent communication success story.",
            type: :short_answer,
            sample_answer: "Presented our internship outcomes to program sponsors and secured continued funding."
          }
        ]
      },
      {
        name: "Career Readiness",
        description: "Progress toward internship, residency, and long-term career goals.",
        questions: [
          {
            order: 1,
            text: "Which career pathways are you actively exploring?",
            type: :multiple_choice,
            options: ["Consulting", "Hospital Administration", "Policy", "Other"],
            sample_answer: ["Hospital Administration", "Policy"]
          },
          {
            order: 2,
            text: "Share one piece of evidence that highlights your career readiness.",
            type: :evidence,
            sample_answer: "https://example.edu/uploads/case-competition-poster.pdf"
          }
        ]
      }
    ]
  }

  survey = Survey.find_or_initialize_by(title: survey_blueprint[:title], semester: survey_blueprint[:semester])
  survey.save!

  categories_with_questions = survey_blueprint[:categories].map do |category_data|
    category = survey.categories.find_or_initialize_by(name: category_data[:name])
    category.description = category_data[:description]
    category.save!

    category_data[:questions].each do |question_data|
      question = category.questions.find_or_initialize_by(question_order: question_data[:order])
      question.question = question_data[:text]
      question.question_type = Question.question_types[question_data[:type]]
      question.answer_options = question_data[:options]&.to_json
      question.save!
    end

    { record: category, blueprint: category_data }
  end

  puts "• Creating survey responses and sample answers"

  student_profiles.each do |student_profile|
    survey_response = SurveyResponse.find_or_initialize_by(student_id: student_profile.student_id, survey_id: survey.id)
    survey_response.advisor_id ||= student_profile.advisor_id
    survey_response.status ||= SurveyResponse.statuses[:in_progress]
    survey_response.completion_date ||= Date.today
    survey_response.save!

    categories_with_questions.each do |category_info|
      category = category_info[:record]

      category_info[:blueprint][:questions].each do |question_data|
        question = category.questions.find_by!(question_order: question_data[:order])
        question_response = QuestionResponse.find_or_initialize_by(
          surveyresponse_id: survey_response.surveyresponse_id,
          question_id: question.question_id
        )

        if question_data[:sample_answer]
          question_response.answer = question_data[:sample_answer]
        end

        question_response.save!
      end

      next if student_profile.advisor_id.nil?

      Feedback.find_or_initialize_by(
        advisor_id: student_profile.advisor_id,
        category_id: category.id,
        surveyresponse_id: survey_response.surveyresponse_id
      ).tap do |feedback|
        feedback.score ||= 4
        feedback.comments ||= "Student shows steady progress in #{category.name.downcase}."
        feedback.save!
      end
    end
  end

  puts "• Admin dashboard helpers updated"
  puts "  Admins:   #{admin_users.map(&:email).join(', ')}"
  puts "  Advisors: #{advisors.map(&:email).join(', ')}"
  puts "  Students: #{student_profiles.map { |s| s.user.email }.join(', ')}"
  puts "  Survey:   #{survey.title} (#{survey.semester})"
end

puts "== Seed data load complete ==\n"
