# frozen_string_literal: true

require "yaml"

sample_path = Rails.root.join("db", "data", "sample_students.yml")
rows = Array(YAML.safe_load_file(sample_path))
sample_emails = rows.filter_map { _1.is_a?(Hash) ? _1["email"].to_s.strip.downcase.presence : nil }.uniq

unless SurveyOffering.data_source_ready?
  warn "SurveyOffering table not present; cannot verify offering-based assignment"
  exit 1
end

now = Time.zone.now
failures = []

Student.includes(:user, survey_assignments: :survey)
  .joins(:user)
  .where("LOWER(users.email) IN (?)", sample_emails)
  .order("users.email ASC")
  .find_each do |student|
    track_key = student.track.to_s
    track_label = ProgramTrack.name_for_key(track_key) || student.read_attribute(:track).to_s
    class_of = student.program_year

    offerings = SurveyOffering.for_student(track_key: track_key, class_of: class_of).includes(:survey)
    expected_ids = offerings.map(&:survey_id).compact.uniq

    assigned = student.survey_assignments.includes(:survey).to_a
    assigned_ids = assigned.map(&:survey_id).compact.uniq

    missing = expected_ids - assigned_ids
    extra = assigned_ids - expected_ids

    offering_from = offerings.each_with_object({}) { |o, memo| memo[o.survey_id] = o.available_from }
    offering_until = offerings.each_with_object({}) { |o, memo| memo[o.survey_id] = o.available_until }

    time_mismatches = assigned.filter_map do |a|
      next unless expected_ids.include?(a.survey_id)

      expected_from = offering_from[a.survey_id]
      expected_until = offering_until[a.survey_id]

      bad = []
      bad << "available_from" if expected_from.present? && a.available_from != expected_from
      bad << "available_until" if expected_until.present? && a.available_until != expected_until

      bad.any? ? [a.survey&.title.to_s, bad.join("/"), a.available_from, expected_from, a.available_until, expected_until] : nil
    end

    open_titles = assigned.select { _1.available_now?(now) }.map { _1.survey&.title.to_s }.sort
    assigned_titles = assigned.map { _1.survey&.title.to_s }.sort
    expected_titles = offerings.map { _1.survey&.title.to_s }.sort

    puts [
      student.user.email,
      "track=#{track_label}",
      "class_of=#{class_of}",
      "open=[#{open_titles.join(", ")}]",
      "assigned=[#{assigned_titles.join(", ")}]",
      "expected=[#{expected_titles.join(", ")}]"
    ].join("\t")

    if missing.any? || extra.any? || time_mismatches.any?
      failures << {
        email: student.user.email,
        track: track_label,
        class_of: class_of,
        missing: missing.map { Survey.find_by(id: _1)&.title }.compact,
        extra: extra.map { Survey.find_by(id: _1)&.title }.compact,
        time_mismatches: time_mismatches
      }
    end
  end

if failures.any?
  warn "\nSurvey assignment verification FAILED: #{failures.size} student(s) have mismatches"
  failures.each do |f|
    warn "- #{f[:email]} (#{f[:track]}, #{f[:class_of]})"
    warn "  missing: #{f[:missing].join(", ")}" if f[:missing].any?
    warn "  extra: #{f[:extra].join(", ")}" if f[:extra].any?
    if f[:time_mismatches].any?
      warn "  time mismatches:"
      f[:time_mismatches].each do |row|
        title, which, got_from, exp_from, got_until, exp_until = row
        warn "    #{title}: #{which} got(from=#{got_from}, until=#{got_until}) expected(from=#{exp_from}, until=#{exp_until})"
      end
    end
  end
  exit 2
end

puts "\nOK: sample students match offering-based survey assignment"
