# frozen_string_literal: true

# NOTE: `Admin` is an ActiveRecord model class in this app (app/models/admin.rb),
# so we define namespaced controllers using `class Admin::X < Admin::BaseController`
# (matching existing admin controllers) rather than `module Admin`.
class Admin::TargetLevelsController < Admin::BaseController
  def index
    @post_save_warning = session.delete(:target_levels_post_save_warning)
    load_selector_options
    load_targets
    @submitted_students_count = submitted_students_count_for_selected_context
  end

  def update
    load_selector_options

    unless @selected_semester_id.present? && @selected_track.present?
      redirect_to admin_target_levels_path, alert: "Select a semester and track before updating target levels."
      return
    end

    competency_titles = Reports::DataAggregator::COMPETENCY_TITLES

    before_targets = CompetencyTargetLevel
      .where(
        program_semester_id: @selected_semester_id,
        track: @selected_track,
        class_of: @selected_class_of,
        competency_title: competency_titles
      )
      .pluck(:competency_title, :target_level)
      .to_h

    targets_payload = params[:targets]

    targets = if targets_payload.respond_to?(:to_unsafe_h)
      targets_payload.to_unsafe_h
    else
      targets_payload
    end

    targets ||= {}

    ActiveRecord::Base.transaction do
      targets.values.each do |entry|
        next unless entry.is_a?(Hash)

        title = entry["competency_title"].to_s
        raw_level = entry["target_level"].to_s.strip

        next if title.blank?

        if raw_level.blank?
          CompetencyTargetLevel.where(
            program_semester_id: @selected_semester_id,
            track: @selected_track,
            class_of: @selected_class_of,
            competency_title: title
          ).delete_all
          next
        end

        level = raw_level.to_i
        record = CompetencyTargetLevel.find_or_initialize_by(
          program_semester_id: @selected_semester_id,
          track: @selected_track,
          class_of: @selected_class_of,
          competency_title: title
        )
        record.target_level = level
        record.save!
      end
    end

    after_targets = CompetencyTargetLevel
      .where(
        program_semester_id: @selected_semester_id,
        track: @selected_track,
        class_of: @selected_class_of,
        competency_title: competency_titles
      )
      .pluck(:competency_title, :target_level)
      .to_h

    if before_targets != after_targets
      submitted_students = submitted_students_count_for_selected_context

      if submitted_students.positive?
        semester_label = @semesters.find { |s| s.id == @selected_semester_id }&.name || "selected semester"
        session[:target_levels_post_save_warning] = "Target levels changed. #{submitted_students} student(s) have already submitted surveys for #{@selected_track} (#{semester_label}); reports may reflect the updated targets."
      end
    end

    redirect_to admin_target_levels_path(
      program_semester_id: @selected_semester_id,
      track: @selected_track,
      class_of: @selected_class_of
    ), notice: "Target levels updated."
  rescue ActiveRecord::RecordInvalid => e
    load_targets
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :index, status: :unprocessable_entity
  end

  private

  def load_selector_options
    @semesters = ProgramSemester.order(Arel.sql("current DESC"), Arel.sql("LOWER(name) ASC"))
    @tracks = Student.tracks.values
    class_years = Student.where.not(class_of: nil).distinct.order(:class_of).pluck(:class_of)
    @class_of_options = [ [ "All classes", "" ] ] + class_years.map { |year| [ "Class of #{year}", year.to_s ] }

    requested_semester_id = params[:program_semester_id].to_s.presence
    @selected_semester_id = requested_semester_id&.to_i
    @selected_track = params[:track].to_s.presence

    year = params[:class_of].to_s.strip
    @selected_class_of = year.present? ? year.to_i : nil
  end

  def load_targets
    unless @selected_semester_id.present? && @selected_track.present?
      @competencies = []
      @targets_by_title = {}
      return
    end

    @competencies = Reports::DataAggregator::COMPETENCY_TITLES

    scoped = CompetencyTargetLevel.where(
      program_semester_id: @selected_semester_id,
      track: @selected_track,
      competency_title: @competencies
    )

    exact = scoped.where(class_of: @selected_class_of).index_by(&:competency_title)
    fallback = @selected_class_of.nil? ? {} : scoped.where(class_of: nil).index_by(&:competency_title)

    @targets_by_title = @competencies.index_with do |title|
      (exact[title] || fallback[title])&.target_level
    end
  end

  def submitted_students_count_for_selected_context
    return 0 unless @selected_semester_id.present? && @selected_track.present?

    submitted_scope = SurveyAssignment
      .joins(:student)
      .joins(survey: :track_assignments)
      .where(surveys: { program_semester_id: @selected_semester_id })
      .where(survey_track_assignments: { track: @selected_track })
      .where(students: { track: @selected_track })
      .where.not(completed_at: nil)

    if @selected_class_of.present?
      submitted_scope = submitted_scope.where(students: { class_of: @selected_class_of })
    end

    submitted_scope.select(:student_id).distinct.count
  end
end
