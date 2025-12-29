# frozen_string_literal: true

# NOTE: `Admin` is an ActiveRecord model class in this app (app/models/admin.rb),
# so we define namespaced controllers using `class Admin::X < Admin::BaseController`
# (matching existing admin controllers) rather than `module Admin`.
class Admin::TargetLevelsController < Admin::BaseController
  def index
    load_selector_options
    load_targets
  end

  def update
    load_selector_options

    unless @selected_semester_id.present? && @selected_track.present?
      redirect_to admin_target_levels_path, alert: "Select a semester and track before updating target levels."
      return
    end

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
            program_year: @selected_program_year,
            competency_title: title
          ).delete_all
          next
        end

        level = raw_level.to_i
        record = CompetencyTargetLevel.find_or_initialize_by(
          program_semester_id: @selected_semester_id,
          track: @selected_track,
          program_year: @selected_program_year,
          competency_title: title
        )
        record.target_level = level
        record.save!
      end
    end

    redirect_to admin_target_levels_path(
      program_semester_id: @selected_semester_id,
      track: @selected_track,
      program_year: @selected_program_year
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
    @program_year_options = [["All years", ""]] + ProgramYear.options_for_select.map { |label, value| [label, value.to_s] }

    requested_semester_id = params[:program_semester_id].to_s.presence
    @selected_semester_id = requested_semester_id&.to_i
    @selected_track = params[:track].to_s.presence

    year = params[:program_year].to_s.strip
    @selected_program_year = year.present? ? year.to_i : nil
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

    exact = scoped.where(program_year: @selected_program_year).index_by(&:competency_title)
    fallback = @selected_program_year.nil? ? {} : scoped.where(program_year: nil).index_by(&:competency_title)

    @targets_by_title = @competencies.index_with do |title|
      (exact[title] || fallback[title])&.target_level
    end
  end
end
