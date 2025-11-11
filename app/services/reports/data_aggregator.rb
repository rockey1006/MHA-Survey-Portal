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
    RECENT_WINDOW = 90.days
    DATASET_SELECT = [
      "student_questions.id",
      "student_questions.id AS student_question_id",
      "student_questions.response_value",
      "student_questions.advisor_id",
      "student_questions.updated_at",
      "categories.id AS category_id",
      "categories.name AS category_name",
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
        students: available_students
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

    # Survey-level achievement details for the course performance section.
    def course_summary
      @course_summary ||= build_course_summary
    end

    # Student vs advisor comparison dataset for the bar chart.
    def alignment
      @alignment ||= build_alignment_payload
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
        course_summary: course_summary,
        alignment: alignment
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
      assign_filter(sanitized, :category_id) do |val|
        id = val.to_i
        id if id.positive?
      end
      assign_filter(sanitized, :student_id) do |val|
        id = val.to_i
        id if id.positive? && accessible_student_ids.include?(id)
      end
      assign_filter(sanitized, :advisor_id) do |val|
        id = val.to_i
        id if id.positive? && accessible_advisor_ids.include?(id)
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
      return Student.all if user.role_admin?

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
      if filters[:category_id]
        scope = scope.where(categories: { id: filters[:category_id] })
      end
      if filters[:student_id]
        scope = scope.where(student_questions: { student_id: filters[:student_id] })
      end
      if filters[:advisor_id]
        scope = scope.where(students: { advisor_id: filters[:advisor_id] })
      end
      scope
    end

    def dataset_rows
      @dataset_rows ||= begin
        rows = []
        filtered_scope.select(DATASET_SELECT).find_each(batch_size: 1_000) do |record|
          next unless (row = build_dataset_row(record))

          rows << row
        end
        rows
      end
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

      if (top = competency_summary.first)
        cards << build_card(
          key: "top_competency",
          title: "Leading Competency",
          value: top[:student_average],
          unit: "score",
          precision: 1,
          change: top[:change],
          description: "Highest-rated competency across filtered data.",
          sample_size: top[:student_sample],
          meta: { name: top[:name], advisor_average: top[:advisor_average], gap: top[:gap] }
        )
      end

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
      grouped = dataset_rows.group_by { |row| row[:category_id] }

      grouped.map do |_category_id, rows|
        name = rows.first[:category_name]
        student_rows = rows.reject { |row| row[:advisor_entry] }
        advisor_rows = rows.select { |row| row[:advisor_entry] }
        student_avg = average(student_rows.map { |row| row[:score] })
        advisor_avg = average(advisor_rows.map { |row| row[:score] })

        student_group = group_student_rows(student_rows)
        attainment_counts = attainment_counts_for_group(student_group)
        attainment_percentages = attainment_percentages(attainment_counts)
        course_breakdown = build_competency_course_breakdown(rows)

        {
          id: rows.first[:category_id],
          name: name,
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
      end.compact.sort_by { |entry| -(entry[:student_average] || 0.0) }
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

    def build_alignment_payload
      categories = dataset_rows.group_by { |row| row[:category_name] }
      labels = categories.keys.sort

      student = []
      advisor = []
      gap = []

      labels.each do |label|
        rows = categories[label]
        student_avg = average(rows.reject { |row| row[:advisor_entry] }.map { |row| row[:score] })
        advisor_avg = average(rows.select { |row| row[:advisor_entry] }.map { |row| row[:score] })
        student << student_avg
        advisor << advisor_avg
        gap << (student_avg && advisor_avg ? (advisor_avg - student_avg) : nil)
      end

      {
        labels: labels,
        student: student,
        advisor: advisor,
        gap: gap
      }
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

    def completion_stats
      return @completion_stats if defined?(@completion_stats)

      scope = scoped_assignment_scope

      total = scope.distinct.count("survey_assignments.id")
      completed = scope.where.not(completed_at: nil).distinct.count("survey_assignments.id")
      rate = total.zero? ? nil : (completed.to_f / total * 100.0)

      @completion_stats = {
        total_assignments: total,
        completed_assignments: completed,
        completion_rate: rate,
        trend: nil
      }
    end

    def available_tracks
      raw_tracks = accessible_student_relation.where.not(track: [ nil, "" ]).pluck(:track)
      sanitize_tracks(raw_tracks)
    end

    def available_semesters
      base_scope.distinct.pluck("surveys.semester").compact.sort
    end

    def available_categories
      base_scope
        .distinct
        .pluck("categories.id", "categories.name")
        .map { |id, name| { id: id, name: name } }
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

    def export_filters
      advisor_map = available_advisors.index_by { |advisor| advisor[:id] }
      category_map = available_categories.index_by { |category| category[:id] }
      survey_map = available_surveys.index_by { |survey| survey[:id] }
      student_map = available_students.index_by { |student| student[:id] }

      {
        track: filters[:track] || "All tracks",
        semester: filters[:semester] || "All semesters",
        advisor: filters[:advisor_id] ? advisor_map[filters[:advisor_id]]&.dig(:name) : "All advisors",
        category: filters[:category_id] ? category_map[filters[:category_id]]&.dig(:name) : "All competencies",
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

    def build_dataset_row(record)
      value = parse_numeric(record.response_value)
      return nil unless value

      {
        id: record.student_question_id,
        score: value,
        advisor_entry: record.advisor_id.present?,
        updated_at: record.updated_at,
        category_id: record.category_id,
        category_name: record.category_name,
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
      student_ids = scoped_student_ids
      return nil if student_ids.blank?

      competency_ids = competency_ids_for_goal
      total_competencies = competency_ids.size
      return nil if total_competencies.zero?

      averages = student_competency_averages
      students_meeting_goal = student_ids.count do |student_id|
        category_avgs = averages[student_id] || {}
        achieved = competency_ids.count do |category_id|
          avg = category_avgs[category_id]
          avg && avg >= TARGET_SCORE
        end
        ratio = achieved.to_f / total_competencies
        ratio >= GOAL_THRESHOLD
      end

      percent = safe_percent(students_meeting_goal, student_ids.size)

      {
        percent: percent,
        goal_percent: PROGRAM_GOAL_PERCENT,
        goal_threshold: GOAL_THRESHOLD,
        total_students: student_ids.size,
        students_meeting_goal: students_meeting_goal
      }
    end

    def student_competency_averages
      @student_competency_averages ||= begin
        per_student = Hash.new { |hash, key| hash[key] = Hash.new { |inner, category| inner[category] = [] } }

        dataset_rows.each do |row|
          next if row[:advisor_entry]
          per_student[row[:student_id]][row[:category_id]] << row[:score]
        end

        per_student.transform_values do |categories|
          categories.transform_values { |scores| average(scores) }
        end
      end
    end

    def competency_ids_for_goal
      if filters[:category_id]
        [ filters[:category_id] ]
      else
        @competency_ids_for_goal ||= Category.order(:id).pluck(:id)
      end
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
