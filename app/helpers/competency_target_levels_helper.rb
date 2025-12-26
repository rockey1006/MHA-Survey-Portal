# frozen_string_literal: true

module CompetencyTargetLevelsHelper
  # Returns the effective competency target level for a question in the context
  # of a survey + student (semester, track, program year).
  #
  # Falls back to Question#program_target_level when no matching
  # CompetencyTargetLevel exists (or when context is missing).
  def effective_competency_target_level(question:, survey:, student:, fallback: nil)
    fallback ||= question&.respond_to?(:program_target_level) ? question.program_target_level : nil
    return fallback unless question && survey && student

    semester_id = survey.respond_to?(:program_semester_id) ? survey.program_semester_id : nil
    track = if student.respond_to?(:track_before_type_cast)
      student.track_before_type_cast
    else
      student[:track]
    end
    title = question.respond_to?(:question_text) ? question.question_text.to_s.strip : ""

    return fallback if semester_id.blank? || track.blank? || title.blank?

    lookup = competency_target_level_lookup(program_semester_id: semester_id, track: track, program_year: student.respond_to?(:program_year) ? student.program_year : nil)
    lookup[title].presence || fallback
  end

  private

  # Memoized per-request lookup for a semester+track+program_year context.
  # Uses year-specific values when present, with a nil-year fallback.
  def competency_target_level_lookup(program_semester_id:, track:, program_year: nil)
    @_competency_target_level_lookup ||= {}

    cache_key = [ program_semester_id, track.to_s, program_year ].freeze
    return @_competency_target_level_lookup[cache_key] if @_competency_target_level_lookup.key?(cache_key)

    titles = Reports::DataAggregator::COMPETENCY_TITLES

    scoped = CompetencyTargetLevel.where(
      program_semester_id: program_semester_id,
      track: track,
      competency_title: titles
    )

    exact_levels = scoped.where(program_year: program_year).pluck(:competency_title, :target_level).to_h
    fallback_levels = program_year.nil? ? {} : scoped.where(program_year: nil).pluck(:competency_title, :target_level).to_h

    # If the student has no program_year recorded, fall back to any available year
    # for that competency (deterministically: lowest program_year). This keeps the
    # UI from hiding target levels when the data exists but the student record is
    # missing program_year.
    any_year_levels = {}
    if program_year.nil?
      scoped.where.not(program_year: nil)
            .order(:program_year)
            .pluck(:competency_title, :target_level, :program_year)
            .each do |row_title, row_level, _row_year|
        any_year_levels[row_title] ||= row_level
      end
    end

    @_competency_target_level_lookup[cache_key] = fallback_levels.merge(any_year_levels).merge(exact_levels)
  end
end
