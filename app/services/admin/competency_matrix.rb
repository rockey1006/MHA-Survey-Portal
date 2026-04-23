# frozen_string_literal: true

class Admin::CompetencyMatrix
  COMPETENCY_TITLES = Reports::DataAggregator::COMPETENCY_TITLES
  DOMAIN_NAMES = Reports::DataAggregator::REPORT_DOMAINS

  def initialize(params: {}, actor_user: nil)
    @params = params.to_h.with_indifferent_access
    @actor_user = actor_user
  end

  def call
    students = filtered_students.to_a
    student_ids = students.map(&:student_id)
    visible_titles = visible_competency_titles
    self_ratings = latest_self_ratings(student_ids)
    advisor_ratings = latest_advisor_ratings(student_ids)
    course_ratings = latest_course_ratings(student_ids)

    {
      filters: normalized_filters,
      filter_options: filter_options,
      domains: domains,
      visible_competency_count: visible_titles.size,
      course_competency_rule: active_course_competency_rule,
      course_competency_rule_label: CourseCompetencyRule.label_for(active_course_competency_rule),
      course_competency_rule_options: CourseCompetencyRule.options,
      students: students.map do |student|
        build_student_row(student, self_ratings:, advisor_ratings:, course_ratings:)
      end
    }
  end

  private

  attr_reader :params, :actor_user

  def build_student_row(student, self_ratings:, advisor_ratings:, course_ratings:)
    {
      id: student.student_id,
      name: student.user&.display_name || student.student_id.to_s,
      email: student.user&.email,
      uin: student.uin,
      track: track_label_for(student),
      program_year: student.program_year,
      advisor_name: student.advisor&.display_name,
      ratings: visible_competency_titles.index_with do |title|
        {
          self_rating: self_ratings.dig(student.student_id, title),
          advisor_rating: advisor_ratings.dig(student.student_id, title),
          course_rating: course_ratings.dig(student.student_id, title)
        }
      end
    }
  end

  def domains
    domain_lookup = competency_domain_lookup

    DOMAIN_NAMES.filter_map do |domain_name|
      competencies = visible_competency_titles.filter_map do |title|
        next unless domain_lookup[title] == domain_name

        { id: competency_slug(title), title: title }
      end

      next if competencies.empty?

      {
        id: competency_slug(domain_name),
        name: domain_name,
        competencies: competencies
      }
    end
  end

  def normalized_filters
    @normalized_filters ||= {
      q: params[:q].to_s.strip,
      track: canonical_track_filter,
      program_year: normalized_program_year,
      advisor_id: normalized_advisor_id,
      semester: normalized_semester,
      domain: normalized_domain,
      competencies: normalized_competencies
    }
  end

  def filter_options
    @filter_options ||= {
      tracks: track_options,
      program_years: program_year_options,
      advisors: advisor_options,
      semesters: semester_options,
      domains: domain_options,
      competencies: competency_options
    }
  end

  def filtered_students
    scope = base_student_scope.includes(:user, advisor: :user).left_outer_joins(:user)

    if normalized_filters[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(normalized_filters[:q])}%"
      scope = scope.where(
        "users.name ILIKE :term OR users.email ILIKE :term OR CAST(students.student_id AS TEXT) ILIKE :term OR students.uin ILIKE :term",
        term: term
      )
    end

    if normalized_filters[:track].present?
      scope = scope.where(track: normalized_filters[:track])
    end

    if normalized_filters[:program_year].present?
      scope = scope.where(program_year: normalized_filters[:program_year])
    end

    if normalized_filters[:advisor_id].present?
      scope = scope.where(advisor_id: normalized_filters[:advisor_id])
    end

    scope.order(Arel.sql("LOWER(COALESCE(users.name, users.email, '')) ASC"), :student_id)
  end

  def latest_self_ratings(student_ids)
    return {} if student_ids.empty?

    rows = StudentQuestion
      .joins(question: { category: { survey: :program_semester } })
      .where(student_id: student_ids, questions: { question_text: visible_competency_titles })
      .select("student_questions.student_id, questions.question_text, student_questions.response_value, student_questions.updated_at, student_questions.id")
      .order("student_questions.student_id ASC, questions.question_text ASC, student_questions.updated_at DESC, student_questions.id DESC")

    if normalized_filters[:semester].present?
      rows = rows.where("LOWER(program_semesters.name) = ?", normalized_filters[:semester].downcase)
    end

    rows.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |row, lookup|
      next if lookup[row.student_id].key?(row.question_text)

      lookup[row.student_id][row.question_text] = normalize_rating(row.response_value)
    end
  end

  def latest_advisor_ratings(student_ids)
    return {} if student_ids.empty?

    rows = Feedback
      .joins(:question, survey: :program_semester)
      .where(student_id: student_ids, questions: { question_text: visible_competency_titles })
      .select("feedback.student_id, questions.question_text, feedback.average_score, feedback.updated_at, feedback.id")
      .order("feedback.student_id ASC, questions.question_text ASC, feedback.updated_at DESC, feedback.id DESC")

    if normalized_filters[:semester].present?
      rows = rows.where("LOWER(program_semesters.name) = ?", normalized_filters[:semester].downcase)
    end

    rows.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |row, lookup|
      next if lookup[row.student_id].key?(row.question_text)

      lookup[row.student_id][row.question_text] = normalize_rating(row.average_score)
    end
  end

  def latest_course_ratings(student_ids)
    return {} if student_ids.empty?

    rows = GradeCompetencyRating
      .joins(:grade_import_batch)
      .merge(GradeImportBatch.reportable)
      .where(student_id: student_ids, competency_title: visible_competency_titles)
      .select("grade_competency_ratings.student_id, grade_competency_ratings.competency_title, grade_competency_ratings.aggregated_level")

    grouped = rows.group_by { |row| [ row.student_id, row.competency_title ] }

    grouped.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |((student_id, competency_title), entries), lookup|
      levels = entries.filter_map { |entry| entry.aggregated_level&.to_f }
      lookup[student_id][competency_title] = CourseCompetencyRule.aggregate(levels, rule_key: active_course_competency_rule)
    end
  end

  def active_course_competency_rule
    @active_course_competency_rule ||= SiteSetting.course_competency_rule
  end

  def normalize_rating(value)
    return nil if value.blank?

    numeric = begin
      Float(value)
    rescue ArgumentError, TypeError
      nil
    end

    return numeric if numeric

    match = value.to_s.match(/([0-5])(?:\D*)\z/)
    match ? match[1].to_f : nil
  end

  def competency_domain_lookup
    @competency_domain_lookup ||= begin
      counts = Question
        .joins(:category)
        .where(question_text: COMPETENCY_TITLES)
        .group(:question_text, "categories.name")
        .count

      grouped = Hash.new { |hash, key| hash[key] = [] }
      counts.each do |(title, domain_name), count|
        grouped[title] << [ domain_name, count ]
      end

      COMPETENCY_TITLES.each_with_object({}) do |title, lookup|
        domain_name = grouped[title]
          .select { |entry| DOMAIN_NAMES.include?(entry.first) }
          .max_by(&:last)
          &.first

        lookup[title] = domain_name
      end
    end
  end

  def track_options
    base_student_scope.where.not(track: nil).distinct.order(:track).pluck(:track)
  end

  def program_year_options
    base_student_scope.where.not(program_year: nil).distinct.order(:program_year).pluck(:program_year)
  end

  def advisor_options
    advisor_ids = base_student_scope.where.not(advisor_id: nil).distinct.order(:advisor_id).pluck(:advisor_id)

    Advisor
      .where(advisor_id: advisor_ids)
      .includes(:user)
      .sort_by { |advisor| advisor.display_name.to_s.downcase }
      .map { |advisor| { id: advisor.advisor_id, name: advisor.display_name } }
  end

  def semester_options
    ProgramSemester.ordered.pluck(:name).compact.uniq
  end

  def domain_options
    domains = competency_domain_lookup.values.compact.uniq
    DOMAIN_NAMES.select { |name| domains.include?(name) }
  end

  def competency_options
    DOMAIN_NAMES.flat_map do |domain_name|
      titles = COMPETENCY_TITLES.select { |title| competency_domain_lookup[title] == domain_name }
      next [] if titles.empty?

      titles.map { |title| { title: title, domain: domain_name } }
    end
  end

  def canonical_track_filter
    value = params[:track].to_s.strip
    return nil if value.blank?

    ProgramTrack.name_for_key(ProgramTrack.canonical_key(value)) || value
  end

  def normalized_program_year
    value = params[:program_year].to_s.strip
    value.present? ? value.to_i : nil
  end

  def normalized_advisor_id
    value = params[:advisor_id].to_s.strip
    value.present? ? value.to_i : nil
  end

  def normalized_semester
    value = params[:semester].to_s.strip
    value.presence
  end

  def normalized_domain
    value = params[:domain].to_s.strip
    value.presence
  end

  def normalized_competencies
    Array(params[:competencies])
      .map { |value| value.to_s.strip }
      .reject(&:blank?)
      .select { |title| COMPETENCY_TITLES.include?(title) }
      .uniq
  end

  def track_label_for(student)
    student[:track].presence || student.track.presence
  end

  def competency_slug(value)
    value.to_s.parameterize(separator: "_")
  end

  def base_student_scope
    @base_student_scope ||= begin
      if actor_user&.role_advisor?
        Student.where(advisor_id: actor_user.id)
      else
        Student.all
      end
    end
  end

  def visible_competency_titles
    @visible_competency_titles ||= begin
      titles = COMPETENCY_TITLES

      if normalized_filters[:domain].present?
        titles = titles.select { |title| competency_domain_lookup[title] == normalized_filters[:domain] }
      end

      if normalized_filters[:competencies].present?
        titles = titles.select { |title| normalized_filters[:competencies].include?(title) }
      end

      titles
    end
  end
end
