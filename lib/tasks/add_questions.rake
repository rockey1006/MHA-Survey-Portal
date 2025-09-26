# Adds three questions to a survey (by survey_id or id).
# Usage:
#   SURVEY=1 bundle exec rake survey:add_questions
# This will try to find Survey by `survey_id` column first, then by primary `id`.
namespace :survey do
  desc "Append three questions to a survey. Use SURVEY=... (survey_id or id)."
  task add_questions: :environment do
    sid_str = ENV["SURVEY"] || ENV["SURVEY_ID"] || "1"
    sid = sid_str.to_i

    survey = Survey.find_by(survey_id: sid) || Survey.find_by(id: sid)
    unless survey
      puts "Survey not found for id: #{sid_str}"
      next
    end

    comp = survey.competencies.first || survey.competencies.create!(name: "Additional questions for survey #{survey.id}", description: "Auto-added by rake task")

    last_order = comp.questions.maximum(:question_order) || 0

    questions = [
      { question_type: "text", question: "Describe one challenge you faced", answer_options: nil },
      { question_type: "radio", question: "Would you recommend this program to a peer?", answer_options: "Yes,No" },
      { question_type: "checkbox", question: "Which resources did you use during the program?", answer_options: "Library,Workshops,Online,Peers" }
    ]

    created = []
    questions.each_with_index do |q, idx|
      qr = comp.questions.create!(question_order: last_order + idx + 1, question_type: q[:question_type], question: q[:question], answer_options: q[:answer_options])
      created << qr
    end

    puts "Added #{created.size} questions to survey id=#{survey.id} (survey_id=#{survey.survey_id}) in competency id=#{comp.id}"
  end
end
