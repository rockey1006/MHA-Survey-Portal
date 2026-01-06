# frozen_string_literal: true

module CompetencyTargetLevelsHelper
  # Returns the effective competency target level for a question in the context
  # of a survey + student (semester, track, class/cohort).
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

    lookup = competency_target_level_lookup(program_semester_id: semester_id, track: track, class_of: student.respond_to?(:class_of) ? student.class_of : nil)
    lookup[title].presence || fallback
  end

  private

  # Memoized per-request lookup for a semester+track+class_of context.
  # Uses class-specific values when present, with a nil-class fallback.
  def competency_target_level_lookup(program_semester_id:, track:, class_of: nil)
    @_competency_target_level_lookup ||= {}

    cache_key = [ program_semester_id, track.to_s, class_of ].freeze
    return @_competency_target_level_lookup[cache_key] if @_competency_target_level_lookup.key?(cache_key)

    titles = Reports::DataAggregator::COMPETENCY_TITLES

    scoped = CompetencyTargetLevel.where(
      program_semester_id: program_semester_id,
      track: track,
      competency_title: titles
    )

    exact_levels = scoped.where(class_of: class_of).pluck(:competency_title, :target_level).to_h
    fallback_levels = class_of.nil? ? {} : scoped.where(class_of: nil).pluck(:competency_title, :target_level).to_h

    # If the student has no class_of recorded, fall back to any available class
    # for that competency (deterministically: lowest class_of). This keeps the
    # UI from hiding target levels when the data exists but the student record is
    # missing class_of.
    any_year_levels = {}
    if class_of.nil?
      scoped.where.not(class_of: nil)
            .order(:class_of)
            .pluck(:competency_title, :target_level, :class_of)
            .each do |row_title, row_level, _row_class|
        any_year_levels[row_title] ||= row_level
      end
    end

    @_competency_target_level_lookup[cache_key] = fallback_levels.merge(any_year_levels).merge(exact_levels)
  end
end
