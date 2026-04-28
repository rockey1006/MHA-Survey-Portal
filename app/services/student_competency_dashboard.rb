# frozen_string_literal: true

require "csv"

class StudentCompetencyDashboard
  COMPETENCY_TITLES = Reports::DataAggregator::COMPETENCY_TITLES
  DOMAIN_NAMES = Reports::DataAggregator::REPORT_DOMAINS

  def initialize(student:, params: {})
    @student = student
    @params = params.to_h.with_indifferent_access
  end

  def call
    {
      student: student,
      filters: filters,
      semesters: semester_options,
      domains: domain_rows,
      radar_chart: radar_chart,
      trend_chart: trend_chart,
      course_released: course_released?,
      release_label: release_label,
      csv: csv
    }
  end

  private

  attr_reader :student, :params

  def filters
    requested_semester = params[:semester].to_s.strip.presence
    selected_semester = requested_semester if semester_options.include?(requested_semester)

    @filters ||= {
      semester: selected_semester || current_semester_name
    }
  end

  def current_semester_name
    current_name = ProgramSemester.current&.name
    return current_name if semester_options.include?(current_name)

    semester_options.first
  end

  def semester_options
    @semester_options ||= begin
      available_semesters = ProgramSemester.ordered.pluck(:name).compact.uniq
      cohort_window = cohort_semester_names.filter_map do |semester_name|
        available_semesters.find { |available_name| available_name.casecmp?(semester_name) }
      end

      cohort_window.presence || available_semesters
    end
  end

  def cohort_semester_names
    return [] if student.program_year.blank?

    start_year = student.program_year.to_i - 1
    [
      "Fall #{start_year}",
      "Spring #{start_year + 1}",
      "Fall #{start_year + 1}",
      "Spring #{start_year + 2}"
    ]
  end

  def selected_program_semester
    @selected_program_semester ||= ProgramSemester.find_by("LOWER(name) = ?", filters[:semester].to_s.downcase)
  end

  def selected_surveys
    @selected_surveys ||= begin
      scope = Survey.includes(:course_grade_release_date)
      scope = scope.where(program_semester_id: selected_program_semester.id) if selected_program_semester
      scope
    end
  end

  def course_released?
    @course_released ||= begin
      release_rows = selected_surveys.map(&:course_grade_release_date).compact
      release_rows.empty? || release_rows.all?(&:released?)
    end
  end

  def release_label
    return "Visible now" if course_released?

    next_release = selected_surveys.filter_map { |survey| survey.course_grade_release_date&.release_at }.min
    next_release ? "Available #{I18n.l(next_release.in_time_zone, format: :long)}" : "Not released"
  end

  def domain_rows
    @domain_rows ||= domain_competencies.map do |domain|
      {
        id: domain[:name].parameterize(separator: "_"),
        name: domain[:name],
        competencies: domain[:competencies].map do |competency|
          title = competency[:title]
          target = target_level_for(title)
          {
            title: title,
            self_rating: self_ratings[title],
            advisor_rating: advisor_ratings[title],
            course_rating: course_released? ? course_ratings[title] : nil,
            course_target: course_released? ? target : nil,
            target_level: target,
            course_sources: course_released? ? course_sources_by_title[title].to_a : []
          }
        end
      }
    end
  end

  def domain_competencies
    rows = Domain.includes(:competencies).ordered.to_a
    if rows.any?
      return rows.map do |domain|
        {
          name: domain.name,
          competencies: domain.competencies.map { |competency| { title: competency.title } }
        }
      end
    end

    DOMAIN_NAMES.map do |domain_name|
      titles = COMPETENCY_TITLES.select { |title| fallback_domain_lookup[title] == domain_name }
      { name: domain_name, competencies: titles.map { |title| { title: title } } }
    end
  end

  def self_rating_scope
    StudentQuestion
      .joins(question: { category: { survey: :program_semester } })
      .where(student_id: student.student_id, questions: { question_text: COMPETENCY_TITLES })
  end

  def self_ratings
    @self_ratings ||= latest_rating_lookup(
      filtered_by_semester(self_rating_scope)
        .select("questions.question_text, student_questions.response_value, student_questions.updated_at, student_questions.id")
        .order("questions.question_text ASC, student_questions.updated_at DESC, student_questions.id DESC"),
      value_method: :response_value
    )
  end

  def advisor_ratings
    @advisor_ratings ||= latest_rating_lookup(
      filtered_by_semester(
        Feedback
          .joins(:question, survey: :program_semester)
          .where(student_id: student.student_id, questions: { question_text: COMPETENCY_TITLES })
      )
        .select("questions.question_text, feedback.average_score, feedback.updated_at, feedback.id")
        .order("questions.question_text ASC, feedback.updated_at DESC, feedback.id DESC"),
      value_method: :average_score
    )
  end

  def course_ratings
    @course_ratings ||= begin
      rows = GradeCompetencyRating
        .joins(:grade_import_batch)
        .merge(GradeImportBatch.reportable)
        .where(student_id: student.student_id, competency_title: COMPETENCY_TITLES)
        .select(:competency_title, :aggregated_level)
      rows = filter_course_rows_by_semester(rows)

      rows.group_by(&:competency_title).transform_values do |ratings|
        CourseCompetencyRule.aggregate(ratings.filter_map { |rating| rating.aggregated_level&.to_f }, rule_key: SiteSetting.course_competency_rule)
      end
    end
  end

  def course_sources_by_title
    @course_sources_by_title ||= begin
      rows = GradeCompetencyEvidence
        .joins(:grade_import_batch)
        .merge(GradeImportBatch.reportable)
        .includes(:grade_import_file)
        .where(student_id: student.student_id, competency_title: COMPETENCY_TITLES)
        .order(:competency_title, :course_code, :assignment_name, :updated_at)
      rows = filter_course_rows_by_semester(rows)

      rows.group_by(&:competency_title).transform_values do |entries|
        entries.map do |entry|
          {
            course_code: entry.course_code.presence || "Unspecified course",
            assignment_name: entry.assignment_name,
            mapped_level: entry.mapped_level,
            raw_grade: entry.raw_grade,
            source_file: entry.grade_import_file&.file_name,
            updated_at: entry.updated_at
          }
        end
      end
    end
  end

  def filter_course_rows_by_semester(scope)
    return scope if selected_program_semester.blank?

    scope.where(grade_import_batches: { program_semester_id: [ selected_program_semester.id, nil ] })
  end

  def target_level_for(title)
    return target_lookup[title] if target_lookup.key?(title)

    nil
  end

  def target_lookup
    @target_lookup ||= begin
      scope = CompetencyTargetLevel.where(competency_title: COMPETENCY_TITLES)
      scope = scope.where(program_semester_id: selected_program_semester.id) if selected_program_semester
      scope = scope.where("LOWER(track) = ?", student.track_key) if student.track_key.present?
      records = scope.to_a

      COMPETENCY_TITLES.index_with do |title|
        matches = records.select { |record| record.competency_title == title }
        exact_year = matches.find { |record| record.program_year == student.program_year }
        exact_class = matches.find { |record| record.class_of == student.program_year }
        fallback = matches.find { |record| record.program_year.blank? && record.class_of.blank? }
        (exact_year || exact_class || fallback || matches.first)&.target_level
      end
    end
  end

  def latest_rating_lookup(rows, value_method:)
    rows.each_with_object({}) do |row, lookup|
      next if lookup.key?(row.question_text)

      lookup[row.question_text] = normalize_rating(row.public_send(value_method))
    end
  end

  def filtered_by_semester(scope)
    return scope if filters[:semester].blank?

    scope.where("LOWER(program_semesters.name) = ?", filters[:semester].downcase)
  end

  def normalize_rating(value)
    return nil if value.blank?

    Float(value)
  rescue ArgumentError, TypeError
    value.to_s[/([0-5])(?:\D*)\z/, 1]&.to_f
  end

  def radar_chart
    labels = COMPETENCY_TITLES
    {
      labels: labels,
      datasets: [
        { label: "Self", data: labels.map { |title| self_ratings[title] } },
        { label: "Advisor", data: labels.map { |title| advisor_ratings[title] } },
        { label: "Course", data: labels.map { |title| course_released? ? course_ratings[title] : nil } },
        { label: "Target", data: labels.map { |title| course_released? ? target_level_for(title) : nil } }
      ]
    }
  end

  def trend_chart
    rows = self_rating_scope
      .select("program_semesters.name AS semester_name, questions.question_text, student_questions.response_value")
      .order("program_semesters.created_at ASC, program_semesters.name ASC")

    semester_names = rows.map(&:semester_name).compact.uniq
    self_by_semester = rows.group_by(&:semester_name).transform_values do |entries|
      values = entries.filter_map { |entry| normalize_rating(entry.response_value) }
      average(values)
    end

    {
      labels: semester_names,
      datasets: [
        { label: "Self average", data: semester_names.map { |name| self_by_semester[name] } }
      ]
    }
  end

  def average(values)
    values = values.compact
    return nil if values.empty?

    (values.sum.to_f / values.size).round(2)
  end

  def csv
    CSV.generate(headers: true) do |csv|
      csv << [
        "Semester",
        "Domain",
        "Competency",
        "Self Rating",
        "Advisor Rating",
        "Course Rating",
        "Course Target",
        "Source Course",
        "Source Competency Level",
        "Source Target Level"
      ]
      domain_rows.each do |domain|
        domain[:competencies].each do |competency|
          source_rows = competency[:course_sources].presence || [ nil ]
          source_rows.each do |source|
            csv << [
              filters[:semester],
              domain[:name],
              competency[:title],
              competency[:self_rating],
              competency[:advisor_rating],
              competency[:course_rating],
              competency[:course_target],
              source&.dig(:course_code),
              source&.dig(:mapped_level),
              competency[:course_target]
            ]
          end
        end
      end
    end
  end

  def fallback_domain_lookup
    @fallback_domain_lookup ||= begin
      {
        "Public and Population Health Assessment" => "Health Care Environment and Community",
        "Delivery, Organization, and Financing of Health Services and Health Systems" => "Health Care Environment and Community",
        "Policy Analysis" => "Health Care Environment and Community",
        "Legal & Ethical Bases for Health Services and Health Systems" => "Health Care Environment and Community",
        "Ethics, Accountability, and Self-Assessment" => "Leadership Skills",
        "Organizational Dynamics" => "Leadership Skills",
        "Problem Solving, Decision Making, and Critical Thinking" => "Leadership Skills",
        "Team Building and Collaboration" => "Leadership Skills",
        "Strategic Planning" => "Management Skills",
        "Business Planning" => "Management Skills",
        "Communication" => "Management Skills",
        "Financial Management" => "Management Skills",
        "Performance Improvement" => "Management Skills",
        "Project Management" => "Management Skills",
        "Systems Thinking" => "Analytic and Technical Skills",
        "Data Analysis and Information Management" => "Analytic and Technical Skills",
        "Quantitative Methods for Health Services Delivery" => "Analytic and Technical Skills"
      }
    end
  end
end
