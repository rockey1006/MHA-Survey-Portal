# Helpers for admin survey editor and detail pages.
module Admin::SurveysHelper
  # @return [Array<(String, String)>] status label and badge classes.
  def admin_survey_status_meta(survey)
    if survey.is_active?
      ["Active", "inline-flex items-center rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-700"]
    else
      ["Archived", "inline-flex items-center rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700"]
    end
  end

  # Formats a survey datetime with a fallback label when blank.
  def admin_survey_datetime(value, fallback: "-")
    value.present? ? l(value, format: :medium) : fallback
  end

  # Resolves the target level shown in the builder for a question.
  # Preference order:
  # 1) CompetencyTargetLevel for survey semester + survey track
  # 2) Explicit question.program_target_level
  # 3) nil
  def resolved_builder_target_level(question:, survey:)
    explicit = question&.respond_to?(:program_target_level) ? question.program_target_level.presence : nil
    return explicit unless question && survey

    title = question.respond_to?(:question_text) ? question.question_text.to_s.strip : ""
    semester_id = survey.respond_to?(:program_semester_id) ? survey.program_semester_id : nil
    return explicit if title.blank? || semester_id.blank?

    track = nil
    if survey.respond_to?(:track_list)
      track = survey.track_list.first.presence
    end
    if track.blank? && survey.respond_to?(:offerings)
      track = survey.offerings.order(:id).pick(:track)
    end
    return explicit if track.blank?

    canonical_track = Survey.canonical_track(track) || track
    class_of = if survey.respond_to?(:offerings)
      survey.offerings.where(track: canonical_track).where.not(class_of: nil).minimum(:class_of)
    end

    lookup = admin_competency_target_level_lookup(
      program_semester_id: semester_id,
      track: canonical_track,
      class_of: class_of
    )

    lookup[title].presence || explicit
  end

  private

  def admin_competency_target_level_lookup(program_semester_id:, track:, class_of: nil)
    @_admin_competency_target_level_lookup ||= {}

    cache_key = [program_semester_id, track.to_s, class_of].freeze
    return @_admin_competency_target_level_lookup[cache_key] if @_admin_competency_target_level_lookup.key?(cache_key)

    scoped = CompetencyTargetLevel.where(program_semester_id: program_semester_id, track: track)

    exact_levels = class_of.present? ? scoped.where(class_of: class_of).pluck(:competency_title, :target_level).to_h : {}
    fallback_levels = scoped.where(class_of: nil).pluck(:competency_title, :target_level).to_h

    any_year_levels = {}
    if class_of.blank?
      scoped.where.not(class_of: nil)
            .order(:class_of)
            .pluck(:competency_title, :target_level, :class_of)
            .each do |title, level, _year|
        any_year_levels[title] ||= level
      end
    end

    @_admin_competency_target_level_lookup[cache_key] = fallback_levels.merge(any_year_levels).merge(exact_levels)
  end
end
