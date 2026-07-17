require "set"
require "json"

puts "== Demo Anonymization =="

FIRST_NAMES = %w[
  Alex Jordan Taylor Morgan Casey Riley Quinn Blake Drew Avery
  Cameron River Sage Harper Logan Parker Reese Kennedy Hayden
  Skyler Finley Emery Ellis Rowan Devon Kendall Peyton Jamie
  Frankie Charlie Sam Leslie Dana Jesse Shawn Tracey Robin Pat
].freeze

LAST_NAMES = %w[
  Smith Johnson Williams Brown Jones Garcia Miller Davis Wilson
  Moore Anderson Jackson Harris Martin Thompson Lee White Clark
  Lewis Robinson Walker Young Allen King Wright Scott Green Baker
  Adams Nelson Hill Ramirez Carter Mitchell Perez Roberts Turner
  Phillips Campbell Evans Edwards Collins Stewart Morris Rogers
].freeze

rng        = Random.new(20_261_001)
used_emails = Set.new(User.pluck(:email).compact)
used_uins   = Set.new(Student.where.not(uin: nil).pluck(:uin))

generate_name = lambda do
  "#{FIRST_NAMES.sample(random: rng)} #{LAST_NAMES.sample(random: rng)}"
end

generate_email = lambda do |name|
  base = name.downcase.gsub(/[^a-z]+/, ".")
  n = 0
  loop do
    candidate = n.zero? ? "#{base}@demo.example.com" : "#{base}#{n}@demo.example.com"
    break candidate unless used_emails.include?(candidate)
    n += 1
  end
end

generate_uin = lambda do
  loop do
    candidate = format("%09d", rng.rand(100_000_000..999_999_999))
    break candidate unless used_uins.include?(candidate)
  end
end

# 1. Anonymize student users + UINs
puts "• Anonymizing student users..."
User.where(role: "student").find_each do |user|
  used_emails.delete(user.email)
  name  = generate_name.call
  email = generate_email.call(name)
  used_emails << email

  user.update_columns(name: name, email: email, uid: email, avatar_url: nil)

  if (student = user.student_profile)
    uin = generate_uin.call
    used_uins << uin
    student.update_column(:uin, uin)
  end
end

# 2. Scrub text survey responses
puts "• Clearing text responses..."
text_q_ids     = Question.where(question_type: "short_answer").pluck(:id)
evidence_q_ids = Question.where(question_type: "evidence").pluck(:id)

StudentQuestion.where(question_id: text_q_ids).update_all(response_value: "Comment here")
StudentQuestion.where(question_id: evidence_q_ids).update_all(response_value: "https://sites.google.com/view/demo-portfolio")

# Scrub "other" free-text from multiple_choice / dropdown JSON payloads
StudentQuestion.where("response_value LIKE ?", '%"text":%').find_each do |sq|
  parsed = JSON.parse(sq.response_value) rescue nil
  next unless parsed.is_a?(Hash) && parsed.key?("text")
  sq.update_column(:response_value, parsed.merge("text" => "Comment here").to_json)
end

# 3. Scrub matching keys in response version snapshots
puts "• Clearing text answers in response version snapshots..."
scrub_keys = (text_q_ids + evidence_q_ids).map(&:to_s).to_set

SurveyResponseVersion.find_each do |version|
  answers = version.answers
  next if answers.blank?

  changed  = false
  scrubbed = answers.each_with_object({}) do |(k, v), memo|
    if scrub_keys.include?(k.to_s)
      memo[k] = "Comment here"
      changed = true
    else
      memo[k] = v
    end
  end

  version.update_column(:answers, scrubbed) if changed
end

# 4. Clear feedback comments
puts "• Clearing feedback comments..."
Feedback.where.not(comments: nil).update_all(comments: "Comment here")

# 5. Clear confidential advisor notes
puts "• Clearing confidential advisor notes..."
ConfidentialAdvisorNote.update_all(body: "Comment here")

puts ""
puts "Done."
puts "  Students anonymized        : #{User.where(role: 'student').count}"
puts "  Text responses scrubbed    : #{StudentQuestion.where(question_id: text_q_ids).count}"
puts "  Evidence responses scrubbed: #{StudentQuestion.where(question_id: evidence_q_ids).count}"
puts "  Version snapshots updated  : #{SurveyResponseVersion.count}"
puts "  Confidential notes cleared : #{ConfidentialAdvisorNote.count}"
