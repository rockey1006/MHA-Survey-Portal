# frozen_string_literal: true

module Reports
  # Aggregates survey response data to support the advisor/admin analytics dashboard
  # and exports. All calculations respect the current user's data access scope
  # and any active filters passed from the client.
  class DataAggregator
    NUMERIC_PATTERN = /\A-?\d+(?:\.\d+)?\z/.freeze
  SCALE_MAX = 5.0
  TARGET_SCORE = 4.0
  PROGRAM_GOAL_PERCENT = 80.0
  GOAL_THRESHOLD = 0.85
  TIMELINE_MONTHS = 3
  COMPETENCY_TITLES = [
    "Public and Population Health Assessment",
    "Delivery, Organization, and Financing of Health Services and Health Systems",
    "Policy Analysis",
    "Legal & Ethical Bases for Health Services and Health Systems",
    "Ethics, Accountability, and Self-Assessment",
    "Organizational Dynamics",
    "Problem Solving, Decision Making, and Critical Thinking",
    "Team Building and Collaboration",
    "Strategic Planning",
    "Business Planning",
    "Communication",
    "Financial Management",
    "Performance Improvement",
    "Project Management",
    "Systems Thinking",
    "Data Analysis and Information Management",
    "Quantitative Methods for Health Services Delivery"
  ].freeze
  REPORT_DOMAINS = [
    "Health Care Environment and Community",
    "Leadership Skills",
    "Management Skills",
    "Analytic and Technical Skills"
  ].freeze
    RECENT_WINDOW = 90.days
    DATASET_SELECT = [
      "student_questions.id",
      "student_questions.id AS student_question_id",
      "student_questions.response_value",
      "student_questions.advisor_id",
      "student_questions.updated_at",
      "categories.id AS category_id",
      "categories.name AS category_name",
      "questions.question_text AS question_text",
      "surveys.id AS survey_id",
      "surveys.title AS survey_title",
      "surveys.semester AS survey_semester",
      "students.track AS student_track",
      "students.student_id AS student_primary_id",
      "students.advisor_id AS owning_advisor_id"
    ].freeze

    FEEDBACK_SELECT = [
      "feedback.id",
      "feedback.id AS student_question_id",
      "feedback.average_score AS response_value",
      "feedback.advisor_id",
      "feedback.updated_at",
      "categories.id AS category_id",
      "categories.name AS category_name",
      "questions.question_text AS question_text",
      "surveys.id AS survey_id",
      "surveys.title AS survey_title",
      "surveys.semester AS survey_semester",
      "students.track AS student_track",
      "students.student_id AS student_primary_id",
      "students.advisor_id AS owning_advisor_id"
    ].freeze

    def initialize(user:, params: {})
      @user = user
      @raw_params = params.to_h.with_indifferent_access
    end

    # Returns the option sets for filter dropdowns.
    def filter_options
      {
        tracks: available_tracks,
        semesters: available_semesters,
        advisors: available_advisors,
        categories: available_categories,
        surveys: available_surveys,
        students: available_students,
        competencies: available_competencies
      }
    end

    # Primary benchmark payload with summary cards and line-chart data.
    def benchmark
      @benchmark ||= build_benchmark_payload
    end

    # High-level competency metrics for the progress grid.
    def competency_summary
      @competency_summary ||= build_competency_summary
    end

    # Detailed competency metrics across the 17 program competencies.
    def competency_detail
      @competency_detail ||= build_competency_detail
    end

    # Survey-level achievement details for the course performance section.
    def course_summary
      @course_summary ||= build_course_summary
    end

    # Track-level aggregate details used by exports.
    def track_summary
      @track_summary ||= build_track_summary
    end

    # Cards for quick overview tiles (alias for convenience).
    def summary_cards
      benchmark[:cards]
    end

    # Comprehensive payload used by PDF/Excel exports.
    def export_payload
      {
        generated_at: Time.current,
        filters: export_filters,
        benchmark: benchmark,
        competency_summary: competency_summary,
        competency_detail: competency_detail,
        course_summary: course_summary,
        track_summary: track_summary
      }
    end

    private

    attr_reader :user

    def filters
      return @filters if defined?(@filters)

      sanitized = {}
      assign_filter(sanitized, :track) { |val| val unless val.casecmp?("all") }
      assign_filter(sanitized, :semester) { |val| val unless val.casecmp?("all") }
      assign_filter(sanitized, :survey_id) do |val|
        id = val.to_i
        id if id.positive?
      end
      assign_filter(sanitized, :category_id) { |val| parse_category_filter(val) }
      assign_filter(sanitized, :student_id) do |val|
        id = val.to_i
        id if id.positive? && accessible_student_ids.include?(id)
      end
      assign_filter(sanitized, :advisor_id) do |val|
        id = val.to_i
        id if id.positive? && accessible_advisor_ids.include?(id)
      end
      assign_filter(sanitized, :competency) do |val|
        slug = normalize_competency_slug(val)
        slug if slug && competency_lookup.key?(slug)
      end

      @filters = sanitized
    end

    def assign_filter(hash, key)
      raw = @raw_params[key]
      return if raw.blank?

      value = yield raw.to_s
      hash[key] = value if value.present?
    end

    def accessible_student_relation
      return Student.none unless user
      return Student.all if user.role_admin? || user.role_advisor?

      advisor = user.advisor_profile
      advisor ? Student.where(advisor_id: advisor.advisor_id) : Student.none
    end

    def accessible_student_ids
      @accessible_student_ids ||= accessible_student_relation.pluck(:student_id)
    end

    def scoped_student_relation
      return @scoped_student_relation if defined?(@scoped_student_relation)

      relation = accessible_student_relation
      relation = relation.where(track: filters[:track]) if filters[:track]
      relation = relation.where(advisor_id: filters[:advisor_id]) if filters[:advisor_id]
      relation = relation.where(student_id: filters[:student_id]) if filters[:student_id]

      if filters[:survey_id] || filters[:semester]
        assignment_students = scoped_assignment_scope.select(:student_id)
        relation = relation.where(student_id: assignment_students)
      end

      @scoped_student_relation = relation.distinct
    end

    def scoped_student_ids
      @scoped_student_ids ||= scoped_student_relation.pluck(:student_id)
    end

    def accessible_advisor_ids
      @accessible_advisor_ids ||= begin
        ids = accessible_student_relation.where.not(advisor_id: nil).distinct.pluck(:advisor_id)
        advisor_id = user&.advisor_profile&.advisor_id
        ids << advisor_id if advisor_id
        ids.compact.uniq
      end
    end

    def base_scope
      StudentQuestion
        .joins(:student)
        .merge(accessible_student_relation)
        .joins(question: { category: :survey })
        .where.not(response_value: [ nil, "" ])
    end

    def filtered_scope
      scope = base_scope
      if filters[:track]
        scope = scope.where(students: { track: filters[:track] })
      end
      if filters[:semester]
        scope = scope.where("LOWER(surveys.semester) = ?", filters[:semester].downcase)
      end
      if filters[:survey_id]
        scope = scope.where(surveys: { id: filters[:survey_id] })
      end
      category_ids = selected_category_ids
      scope = scope.where(categories: { id: category_ids }) if category_ids.present?
      if filters[:competency]
        competency_name = competency_lookup[filters[:competency]]&.dig(:name)
        if competency_name.present?
          scope = scope.where("LOWER(questions.question_text) = ?", competency_name.downcase)
        end
      end
      if filters[:student_id]
        scope = scope.where(student_questions: { student_id: filters[:student_id] })
      end
      if filters[:advisor_id]
        scope = scope.where(students: { advisor_id: filters[:advisor_id] })
      end
      scope
    end

    def feedback_scope
      Feedback
        .joins(:student)
        .merge(accessible_student_relation)
        .joins(:question)
        .joins(question: { category: :survey })
        .where.not(average_score: nil)
    end

    def filtered_feedback_scope
      scope = feedback_scope
      if filters[:track]
        scope = scope.where(students: { track: filters[:track] })
      end
      if filters[:semester]
        scope = scope.where("LOWER(surveys.semester) = ?", filters[:semester].downcase)
      end
      if filters[:survey_id]
        scope = scope.where(surveys: { id: filters[:survey_id] })
      end
      category_ids = selected_category_ids
      scope = scope.where(categories: { id: category_ids }) if category_ids.present?
      if filters[:competency]
        competency_name = competency_lookup[filters[:competency]]&.dig(:name)
        if competency_name.present?
          scope = scope.where("LOWER(questions.question_text) = ?", competency_name.downcase)
        end
      end
      if filters[:student_id]
        scope = scope.where(feedback: { student_id: filters[:student_id] })
      end
      if filters[:advisor_id]
        scope = scope.where(feedback: { advisor_id: filters[:advisor_id] })
      end
      scope
    end

    def dataset_rows
      @dataset_rows ||= begin
        rows = []
        filtered_scope.select(DATASET_SELECT).find_each(batch_size: 1_000) do |record|
          next unless (row = build_dataset_row(record, is_advisor_entry: false))

          rows << row
        end
        filtered_feedback_scope.select(FEEDBACK_SELECT).find_each(batch_size: 1_000) do |record|
          next unless (row = build_dataset_row(record, is_advisor_entry: true))

          rows << row
        end
        rows
      end
    end

    def student_response_groups
      @student_response_groups ||= group_student_rows(dataset_rows.reject { |row| row[:advisor_entry] })
    end

    def student_survey_response_pairs
      @student_survey_response_pairs ||= begin
        filtered_scope
          .distinct
          .pluck("student_questions.student_id", "surveys.id")
          .each_with_object({}) do |(student_id, survey_id), memo|
            next unless student_id && survey_id

            memo[[ student_id, survey_id ]] = true
          end
      end
    end

    def assignment_pair_key(student_id, survey_id)
      return nil if student_id.blank? || survey_id.blank?

      [ student_id, survey_id ]
    end

    def parse_numeric(value)
      str = value.to_s.strip
      return nil unless NUMERIC_PATTERN.match?(str)

      str.to_f
    rescue StandardError
      nil
    end

    def average(values)
      return nil if values.blank?

      values.sum.to_f / values.size
    end

    def safe_percent(numerator, denominator)
      return nil if denominator.to_f.zero?

      (numerator.to_f / denominator.to_f) * 100.0
    end

    def alignment_percent(student_avg, advisor_avg)
      return nil if student_avg.nil? || advisor_avg.nil?

      gap = (student_avg - advisor_avg).abs
      normalized = [ SCALE_MAX - [ gap, SCALE_MAX ].min, 0 ].max
      (normalized / SCALE_MAX) * 100.0
    end

    def build_benchmark_payload
      Rails.logger.debug "--- Starting build_benchmark_payload ---"
      Rails.logger.debug "Filters applied: #{@raw_params.inspect}"
      Rails.logger.debug "Dataset rows count: #{dataset_rows.size}"

      student_scores = dataset_rows.reject { |row| row[:advisor_entry] }.map { |row| row[:score] }
      advisor_scores = dataset_rows.select { |row| row[:advisor_entry] }.map { |row| row[:score] }

      student_avg = average(student_scores)
      advisor_avg = average(advisor_scores)
      alignment_pct = alignment_percent(student_avg, advisor_avg)

      cards = []
      cards << build_card(
        key: "overall_average",
        title: "Overall Student Average",
        value: student_avg,
        unit: "score",
        precision: 1,
        change: percent_change_for(:student),
        description: "Mean student competency score on a five-point scale.",
        sample_size: student_scores.size
      )

      cards << build_card(
        key: "advisor_alignment",
        title: "Student & Advisor Alignment",
        value: alignment_pct,
        unit: "percent",
        precision: 0,
        change: alignment_trend_change,
        description: "Closeness of student and advisor averages (100% = perfect alignment).",
        sample_size: [ student_scores.size, advisor_scores.size ].min
      )

      completion_stats = completion_stats()
      cards << build_card(
        key: "completion_rate",
        title: "Survey Completion",
        value: completion_stats[:completion_rate],
        unit: "percent",
        precision: 0,
        change: completion_stats[:trend],
        description: "Percent of assigned surveys submitted.",
        sample_size: completion_stats[:total_assignments]
      )

      goal_metric = competency_goal_metric
      Rails.logger.debug "Competency Goal Metric: #{goal_metric.inspect}"

      if (goal_metric = competency_goal_metric)
        cards << build_card(
          key: "competency_goal_attainment",
          title: "Students Meeting Competency Goal",
          value: goal_metric[:percent],
          unit: "percent",
          precision: 0,
          change: goal_metric[:percent] && goal_metric[:goal_percent] ? (goal_metric[:percent] - goal_metric[:goal_percent]) : nil,
          description: "Percent of students achieving ≥85% of competencies. Program goal: #{goal_metric[:goal_percent]}%.",
          sample_size: goal_metric[:total_students],
          meta: {
            goal_percent: goal_metric[:goal_percent],
            goal_threshold: goal_metric[:goal_threshold],
            students_met_goal: goal_metric[:students_meeting_goal]
          }
        )
      end

      competency_summary_data = competency_summary
      Rails.logger.debug "Competency Summary (for Leading Competency card): #{competency_summary_data.first.inspect}"

      Rails.logger.debug "--- Finished build_benchmark_payload ---"

      {
        student_average: student_avg,
        advisor_average: advisor_avg,
        alignment_percent: alignment_pct,
        completion_rate: completion_stats[:completion_rate],
        cards: cards.compact,
        timeline: build_timeline,
        sample_size_student: student_scores.size,
        sample_size_advisor: advisor_scores.size
      }
    end

    def build_card(key:, title:, value:, unit:, precision:, description:, change:, sample_size:, meta: nil)
      return nil if value.nil?

      {
        key: key,
        title: title,
        value: value,
        unit: unit,
        precision: precision,
        description: description,
        change: change,
        change_direction: change_direction(change),
        sample_size: sample_size,
        meta: meta
      }
    end

    def change_direction(change)
      return "flat" if change.nil?
      return "up" if change.positive?
      return "down" if change.negative?

      "flat"
    end

    def percent_change_for(role)
      role_key = role == :advisor ? :advisor_entry : :student_entry
      recent_range = (Time.current - RECENT_WINDOW)..Time.current
      previous_range = (Time.current - (RECENT_WINDOW * 2))...(Time.current - RECENT_WINDOW)

      recent_scores = scores_for(role_key, recent_range)
      previous_scores = scores_for(role_key, previous_range)

      recent_avg = average(recent_scores)
      previous_avg = average(previous_scores)

      return nil if recent_avg.nil? || previous_avg.nil? || previous_avg.zero?

      ((recent_avg - previous_avg) / previous_avg) * 100.0
    end

    def scores_for(role_key, range)
      dataset_rows.filter do |row|
        matches_role = role_key == :advisor_entry ? row[:advisor_entry] : !row[:advisor_entry]
        matches_role && range.cover?(row[:updated_at])
      end.map { |row| row[:score] }
    end

    def build_timeline
      return [] if dataset_rows.empty?

      buckets = Hash.new { |hash, key| hash[key] = { student: [], advisor: [] } }

      dataset_rows.each do |row|
        month = row[:updated_at].in_time_zone.beginning_of_month
        bucket = buckets[month]
        if row[:advisor_entry]
          bucket[:advisor] << row[:score]
        else
          bucket[:student] << row[:score]
        end
      end

      buckets.keys.sort.last(TIMELINE_MONTHS).map do |month|
        student_avg = average(buckets[month][:student])
        advisor_avg = average(buckets[month][:advisor])
        {
          label: month.strftime("%b %Y"),
          student: student_avg,
          advisor: advisor_avg,
          alignment: alignment_percent(student_avg, advisor_avg)
        }
      end
    end

    def alignment_trend_change
      timeline = build_timeline
      return nil unless timeline.size >= 2

      latest = timeline[-1][:alignment]
      previous = timeline[-2][:alignment]
      return nil if latest.nil? || previous.nil?

      latest - previous
    end

    def build_competency_summary
      Rails.logger.debug "--- Building Competency Summary ---"
      grouped = Hash.new { |hash, key| hash[key] = { rows: [], category_ids: [] } }

      dataset_rows.each do |row|
        slug = category_id_to_slug[row[:category_id]] || normalize_domain_slug(row[:category_name]) || "category_#{row[:category_id]}"
        entry = grouped[slug]
        entry[:rows] << row
        entry[:category_ids] << row[:category_id]
        entry[:name] ||= category_group_lookup[slug]&.dig(:name) || row[:category_name] || "Domain"
      end

      summary = grouped.map do |slug, data|
        rows = data[:rows]
        next if rows.blank?

        student_rows = rows.reject { |row| row[:advisor_entry] }
        advisor_rows = rows.select { |row| row[:advisor_entry] }
        student_avg = average(student_rows.map { |row| row[:score] })
        advisor_avg = average(advisor_rows.map { |row| row[:score] })

        student_group = group_student_rows(student_rows)
        attainment_counts = attainment_counts_for_group(student_group)
        attainment_percentages = attainment_percentages(attainment_counts)
        course_breakdown = build_competency_course_breakdown(rows)

        {
          id: slug,
          name: data[:name],
          category_ids: data[:category_ids].uniq,
          student_average: student_avg,
          advisor_average: advisor_avg,
          gap: advisor_avg && student_avg ? (advisor_avg - student_avg) : nil,
          change: percent_change_for_category(rows),
          status: student_avg && student_avg >= TARGET_SCORE ? "on_track" : "watch",
          student_sample: student_rows.size,
          advisor_sample: advisor_rows.size,
          achieved_count: attainment_counts[:achieved_count],
          not_met_count: attainment_counts[:not_met_count],
          not_assessed_count: attainment_counts[:not_assessed_count],
          achieved_percent: attainment_percentages[:achieved_percent],
          not_met_percent: attainment_percentages[:not_met_percent],
          not_assessed_percent: attainment_percentages[:not_assessed_percent],
          total_students: attainment_counts[:total_students],
          courses: course_breakdown
        }
      end.compact.select { |entry| REPORT_DOMAINS.include?(entry[:name]) }.sort_by { |entry| -(entry[:student_average] || 0.0) }

      Rails.logger.debug "Generated competency summary: #{summary.inspect}"
      summary
    end

    def percent_change_for_category(rows)
      recent_range = (Time.current - RECENT_WINDOW)..Time.current
      previous_range = (Time.current - (RECENT_WINDOW * 2))...(Time.current - RECENT_WINDOW)

      recent_scores = rows.filter { |row| !row[:advisor_entry] && recent_range.cover?(row[:updated_at]) }.map { |row| row[:score] }
      previous_scores = rows.filter { |row| !row[:advisor_entry] && previous_range.cover?(row[:updated_at]) }.map { |row| row[:score] }

      recent_avg = average(recent_scores)
      previous_avg = average(previous_scores)
      return nil if recent_avg.nil? || previous_avg.nil? || previous_avg.zero?

      ((recent_avg - previous_avg) / previous_avg) * 100.0
    end



    def build_competency_detail
      Rails.logger.debug "--- Building Competency Detail ---"
      buckets = Hash.new do |hash, key|
        hash[key] = {
          student_rows: [],
          advisor_rows: [],
          domain_name: nil,
          domain_slug: nil
        }
      end

      dataset_rows.each do |row|
        slug = competency_slug(row[:question_text])
        next unless slug && competency_lookup.key?(slug)

        bucket = buckets[slug]
        bucket[:domain_name] ||= row[:category_name]
        bucket[:domain_slug] ||= category_id_to_slug[row[:category_id]] || normalize_domain_slug(row[:category_name])
        if row[:advisor_entry]
          bucket[:advisor_rows] << row
        else
          bucket[:student_rows] << row
        end
      end

      items = COMPETENCY_TITLES.map do |title|
        slug = competency_slug(title)
        bucket = buckets[slug]
        student_rows = bucket&.dig(:student_rows) || []
        advisor_rows = bucket&.dig(:advisor_rows) || []

        student_avg = average(student_rows.map { |row| row[:score] })
        advisor_avg = average(advisor_rows.map { |row| row[:score] })

        student_group = group_student_rows(student_rows)
        attainment_counts = attainment_counts_for_group(student_group)
        attainment_percentages = attainment_percentages(attainment_counts)

        {
          id: slug,
          name: title,
          domain_id: bucket&.dig(:domain_slug),
          domain_name: bucket&.dig(:domain_name),
          student_average: student_avg,
          advisor_average: advisor_avg,
          gap: advisor_avg && student_avg ? (advisor_avg - student_avg) : nil,
          achieved_count: attainment_counts[:achieved_count],
          not_met_count: attainment_counts[:not_met_count],
          not_assessed_count: attainment_counts[:not_assessed_count],
          achieved_percent: attainment_percentages[:achieved_percent],
          not_met_percent: attainment_percentages[:not_met_percent],
          not_assessed_percent: attainment_percentages[:not_assessed_percent],
          total_students: attainment_counts[:total_students]
        }
      end

      detail = {
        domains: available_categories.map { |entry| { id: entry[:id], name: entry[:name] } },
        items: items
      }
      Rails.logger.debug "Generated competency detail: #{detail.inspect}"
      detail
    end

    def build_course_summary
      surveys = dataset_rows.group_by { |row| row[:survey_id] }

      surveys.map do |_survey_id, rows|
        survey_meta = rows.first
        student_rows = rows.reject { |row| row[:advisor_entry] }
        advisor_rows = rows.select { |row| row[:advisor_entry] }

        student_avg = average(student_rows.map { |row| row[:score] })
        advisor_avg = average(advisor_rows.map { |row| row[:score] })

        student_by_person = group_student_rows(student_rows)
        attainment_counts = attainment_counts_for_group(student_by_person)
        attainment_percentages = attainment_percentages(attainment_counts)
        competency_breakdown = build_course_competency_breakdown(rows)

        {
          id: survey_meta[:survey_id],
          title: survey_meta[:survey_title],
          semester: survey_meta[:survey_semester],
          track: survey_meta[:track],
          student_average: student_avg,
          advisor_average: advisor_avg,
          submissions: student_by_person.size,
          on_track_percent: attainment_percentages[:achieved_percent],
          achieved_count: attainment_counts[:achieved_count],
          not_met_count: attainment_counts[:not_met_count],
          not_assessed_count: attainment_counts[:not_assessed_count],
          achieved_percent: attainment_percentages[:achieved_percent],
          not_met_percent: attainment_percentages[:not_met_percent],
          not_assessed_percent: attainment_percentages[:not_assessed_percent],
          total_students: attainment_counts[:total_students],
          gap: advisor_avg && student_avg ? (advisor_avg - student_avg) : nil,
          competencies: competency_breakdown
        }
      end.compact.sort_by { |entry| -(entry[:student_average] || 0.0) }
    end

    def build_track_summary
      tracks = dataset_rows.group_by { |row| row[:track] }

      tracks.map do |track_name, rows|
        next if rows.blank?

        student_rows = rows.reject { |row| row[:advisor_entry] }
        advisor_rows = rows.select { |row| row[:advisor_entry] }

        student_avg = average(student_rows.map { |row| row[:score] })
        advisor_avg = average(advisor_rows.map { |row| row[:score] })

        student_by_person = group_student_rows(student_rows)
        attainment_counts = attainment_counts_for_group(student_by_person)
        attainment_percentages = attainment_percentages(attainment_counts)

        {
          id: track_name.parameterize(separator: "_")
            .presence || "track_#{track_name.object_id}",
          track: track_name,
          student_average: student_avg,
          advisor_average: advisor_avg,
          gap: advisor_avg && student_avg ? (advisor_avg - student_avg) : nil,
          submissions: student_by_person.size,
          achieved_count: attainment_counts[:achieved_count],
          not_met_count: attainment_counts[:not_met_count],
          not_assessed_count: attainment_counts[:not_assessed_count],
          achieved_percent: attainment_percentages[:achieved_percent],
          not_met_percent: attainment_percentages[:not_met_percent],
          not_assessed_percent: attainment_percentages[:not_assessed_percent],
          total_students: attainment_counts[:total_students]
        }
      end.compact.sort_by { |entry| entry[:track].to_s }
    end

    def completion_stats
      return @completion_stats if defined?(@completion_stats)

      assignments = scoped_assignment_scope
                    .select(:student_id, :survey_id, :completed_at)
                    .distinct
                    .to_a

      assignment_pairs = assignments.each_with_object({}) do |assignment, memo|
        key = assignment_pair_key(assignment.student_id, assignment.survey_id)
        memo[key] = assignment if key
      end

      response_pairs = student_survey_response_pairs
      combined_keys = (assignment_pairs.keys + response_pairs.keys).uniq

      if assignment_pairs.empty?
        total = scoped_student_ids.size
        completed = student_response_groups.keys.size
      else
        total = combined_keys.size
        total = scoped_student_ids.size if total.zero?
        completed = combined_keys.count do |key|
          assignment = assignment_pairs[key]
          assignment&.completed_at.present? || response_pairs[key]
        end
      end

      rate = total.to_f.zero? ? nil : (completed.to_f / total.to_f * 100.0)

      stats = {
        total_assignments: total,
        completed_assignments: completed,
        completion_rate: rate,
        trend: nil
      }
      Rails.logger.debug "Completion Stats: #{stats.inspect}"
      @completion_stats = stats
    end

    def available_tracks
      raw_tracks = accessible_student_relation.where.not(track: [ nil, "" ]).pluck(:track)
      sanitize_tracks(raw_tracks)
    end

    def normalized_track_name(value)
      text = value.to_s.strip
      text.presence || "Unspecified Track"
    end

    def available_semesters
      base_scope.distinct.pluck("surveys.semester").compact.sort
    end

    def available_categories
      category_group_lookup
        .values
        .select { |entry| REPORT_DOMAINS.include?(entry[:name]) }
        .map { |entry| { id: entry[:id], name: entry[:name], category_ids: entry[:ids] } }
        .sort_by { |entry| entry[:name].to_s.downcase }
    end

    def available_surveys
      base_scope
        .distinct
        .pluck("surveys.id", "surveys.title", "surveys.semester")
        .map { |id, title, semester| { id: id, title: title, semester: semester } }
        .sort_by { |entry| entry[:title].to_s.downcase }
    end

    def available_advisors
      Advisor
        .where(advisor_id: accessible_advisor_ids)
        .includes(:user)
        .map { |advisor| { id: advisor.advisor_id, name: advisor.display_name } }
        .sort_by { |entry| entry[:name].to_s.downcase }
    end

    def available_students
      accessible_student_relation
        .includes(:user)
        .map do |student|
          {
            id: student.student_id,
            name: student.user.display_name,
            track: student.track,
            advisor_id: student.advisor_id
          }
        end
        .sort_by { |entry| entry[:name].to_s.downcase }
    end

    def available_competencies
      COMPETENCY_TITLES.map do |title|
        {
          id: competency_slug(title),
          name: title
        }
      end
    end

    def competency_lookup
      @competency_lookup ||= available_competencies.index_by { |entry| entry[:id] }
    end

    def domain_slug(value)
      value.to_s.parameterize(separator: "_")
    end

    def normalize_domain_slug(value)
      slug = domain_slug(value)
      slug.presence
    end

    def category_group_lookup
      return @category_group_lookup if defined?(@category_group_lookup)

      groups = {}

      base_scope
        .distinct
        .pluck("categories.id", "categories.name")
        .each do |id, name|
          next unless id && name.present?

          slug = normalize_domain_slug(name)
          next unless slug

          entry = groups[slug] ||= { id: slug, name: name, ids: [] }
          entry[:name] ||= name
          entry[:ids] << id
        end

      groups.each_value { |entry| entry[:ids].uniq! }

      @category_group_lookup = groups
    end

    def category_id_to_slug
      return @category_id_to_slug if defined?(@category_id_to_slug)

      mapping = {}
      category_group_lookup.each do |slug, entry|
        entry[:ids].each { |id| mapping[id] = slug }
      end

      @category_id_to_slug = mapping
    end

    def parse_category_filter(raw)
      value = raw.to_s.strip
      return nil if value.blank? || value.casecmp?("all")

      if value.match?(/\A\d+\z/)
        slug = category_id_to_slug[value.to_i]
        return slug if slug
      end

      slug = normalize_domain_slug(value)
      return slug if slug && category_group_lookup.key?(slug)

      nil
    end

    def selected_category_ids
      slug = filters[:category_id]
      return [] unless slug

      category_group_lookup[slug]&.dig(:ids) || []
    end

    def normalize_competency_slug(value)
      competency_slug(value).presence
    end

    def normalized_competency_title(value)
      text = value.to_s.strip
      return text if text.blank?

      text.sub(/\s+Reflection\z/i, "")
    end

    def competency_slug(value)
      normalized_competency_title(value).to_s.parameterize(separator: "_")
    end

    def export_filters
      advisor_map = available_advisors.index_by { |advisor| advisor[:id] }
      category_map = available_categories.index_by { |category| category[:id] }
      survey_map = available_surveys.index_by { |survey| survey[:id] }
      student_map = available_students.index_by { |student| student[:id] }
      competency_map = available_competencies.index_by { |entry| entry[:id] }

      {
        track: filters[:track] || "All tracks",
        semester: filters[:semester] || "All semesters",
        advisor: filters[:advisor_id] ? advisor_map[filters[:advisor_id]]&.dig(:name) : "All advisors",
        domain: filters[:category_id] ? category_map[filters[:category_id]]&.dig(:name) : "All domains",
        competency: filters[:competency] ? competency_map[filters[:competency]]&.dig(:name) : "All competencies",
        survey: filters[:survey_id] ? format_survey_label(survey_map[filters[:survey_id]]) : "All surveys",
        student: filters[:student_id] ? student_map[filters[:student_id]]&.dig(:name) : "All students"
      }
    end

    def format_survey_label(entry)
      return nil unless entry

      [ entry[:title], entry[:semester] ].compact.join(" · ")
    end

    def build_competency_course_breakdown(rows)
      rows.group_by { |row| row[:survey_id] }.map do |_survey_id, survey_rows|
        student_rows = survey_rows.reject { |row| row[:advisor_entry] }
        advisor_rows = survey_rows.select { |row| row[:advisor_entry] }
        student_group = group_student_rows(student_rows)
        counts = attainment_counts_for_group(student_group)
        percents = attainment_percentages(counts)

        {
          id: survey_rows.first[:survey_id],
          title: survey_rows.first[:survey_title],
          semester: survey_rows.first[:survey_semester],
          student_average: average(student_rows.map { |row| row[:score] }),
          advisor_average: average(advisor_rows.map { |row| row[:score] }),
          achieved_count: counts[:achieved_count],
          not_met_count: counts[:not_met_count],
          not_assessed_count: counts[:not_assessed_count],
          achieved_percent: percents[:achieved_percent],
          not_met_percent: percents[:not_met_percent],
          not_assessed_percent: percents[:not_assessed_percent]
        }
      end.sort_by { |course| course[:title].to_s.downcase }
    end

    def build_course_competency_breakdown(rows)
      rows.group_by { |row| row[:category_id] }.map do |_category_id, category_rows|
        student_rows = category_rows.reject { |row| row[:advisor_entry] }
        advisor_rows = category_rows.select { |row| row[:advisor_entry] }
        student_group = group_student_rows(student_rows)
        counts = attainment_counts_for_group(student_group)
        percents = attainment_percentages(counts)

        {
          id: category_rows.first[:category_id],
          name: category_rows.first[:category_name],
          student_average: average(student_rows.map { |row| row[:score] }),
          advisor_average: average(advisor_rows.map { |row| row[:score] }),
          achieved_count: counts[:achieved_count],
          not_met_count: counts[:not_met_count],
          not_assessed_count: counts[:not_assessed_count],
          achieved_percent: percents[:achieved_percent],
          not_met_percent: percents[:not_met_percent],
          not_assessed_percent: percents[:not_assessed_percent]
        }
      end.sort_by { |competency| competency[:name].to_s.downcase }
    end

    def build_dataset_row(record, is_advisor_entry: false)
      value = parse_numeric(record.response_value)
      return nil unless value

      {
        id: record.student_question_id,
        score: value,
        advisor_entry: is_advisor_entry,
        updated_at: record.updated_at,
        category_id: record.category_id,
        category_name: record.category_name,
        question_text: record.question_text,
        survey_id: record.survey_id,
        survey_title: record.survey_title,
        survey_semester: record.survey_semester,
        track: record.student_track,
        student_id: record.student_primary_id,
        advisor_id: record.owning_advisor_id || record.advisor_id
      }
    end

    def sanitize_tracks(values)
      values
        .filter_map { |value| normalize_track(value) }
        .uniq { |value| value.downcase }
        .sort_by { |value| value.downcase }
    end

    def normalize_track(value)
      trimmed = value.to_s.strip
      trimmed.presence
    end

    def group_student_rows(rows)
      rows.reject { |row| row[:student_id].blank? }
          .group_by { |row| row[:student_id] }
    end

    def attainment_counts_for_group(student_rows_group)
      achieved = 0
      not_met = 0

      student_rows_group.each_value do |entries|
        avg = average(entries.map { |row| row[:score] })
        next if avg.nil?

        if avg >= TARGET_SCORE
          achieved += 1
        else
          not_met += 1
        end
      end

      assessed = achieved + not_met
      total_students = scoped_student_ids.size
      not_assessed = [ total_students - assessed, 0 ].max

      {
        achieved_count: achieved,
        not_met_count: not_met,
        not_assessed_count: not_assessed,
        total_students: total_students
      }
    end

    def attainment_percentages(counts)
      total = counts[:total_students]
      return { achieved_percent: nil, not_met_percent: nil, not_assessed_percent: nil } if total.zero?

      {
        achieved_percent: safe_percent(counts[:achieved_count], total),
        not_met_percent: safe_percent(counts[:not_met_count], total),
        not_assessed_percent: safe_percent(counts[:not_assessed_count], total)
      }
    end

    def competency_goal_metric
      Rails.logger.debug "--- Calculating competency_goal_metric ---"
      student_ids = scoped_student_ids
      Rails.logger.debug "Scoped student IDs for goal metric: #{student_ids.inspect}"
      return nil if student_ids.blank?

      averages = student_competency_averages
      Rails.logger.debug "Student competency averages for goal: #{averages.inspect}"
      competency_slugs = competency_ids_for_goal(averages)
      Rails.logger.debug "Competency slugs for goal: #{competency_slugs.inspect}"
      total_competencies = competency_slugs.size
      return nil if total_competencies.zero?

      students_meeting_goal = student_ids.count do |student_id|
        competency_avgs = averages[student_id] || {}
        achieved = competency_slugs.count do |slug|
          avg = competency_avgs[slug]
          avg && avg >= TARGET_SCORE
        end
        ratio = achieved.to_f / total_competencies
        Rails.logger.debug "Student #{student_id} achieved ratio: #{ratio}"
        ratio >= GOAL_THRESHOLD
      end

      percent = safe_percent(students_meeting_goal, student_ids.size)

      result = {
        percent: percent,
        goal_percent: PROGRAM_GOAL_PERCENT,
        goal_threshold: GOAL_THRESHOLD,
        total_students: student_ids.size,
        students_meeting_goal: students_meeting_goal
      }
      Rails.logger.debug "Final competency_goal_metric result: #{result.inspect}"
      result
    end

    def student_competency_averages
      @student_competency_averages ||= begin
        per_student = Hash.new { |hash, key| hash[key] = Hash.new { |inner, slug| inner[slug] = [] } }

        dataset_rows.each do |row|
          next if row[:advisor_entry]
          slug = competency_slug(row[:question_text])
          next unless slug && competency_lookup.key?(slug)

          per_student[row[:student_id]][slug] << row[:score]
        end

        per_student.transform_values do |competencies|
          competencies.transform_values { |scores| average(scores) }
        end
      end
    end

    def competency_ids_for_goal(averages = nil)
      return [ filters[:competency] ] if filters[:competency]

      averages ||= student_competency_averages
      present_slugs = averages.values.flat_map(&:keys).uniq.compact
      present_slugs.presence || competency_lookup.keys
    end

    def scoped_assignment_scope
      scope = SurveyAssignment
              .joins(:survey, :student)
              .where(student_id: accessible_student_relation.select(:student_id))

      scope = scope.where(students: { track: filters[:track] }) if filters[:track]
      scope = scope.where(students: { advisor_id: filters[:advisor_id] }) if filters[:advisor_id]
      scope = scope.where(student_id: filters[:student_id]) if filters[:student_id]
      scope = scope.where(surveys: { id: filters[:survey_id] }) if filters[:survey_id]
      if filters[:semester]
        scope = scope.where("LOWER(surveys.semester) = ?", filters[:semester].downcase)
      end

      scope
    end
  end
end
