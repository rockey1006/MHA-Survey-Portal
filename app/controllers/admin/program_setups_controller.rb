# Program configuration hub for admins (tracks, majors, years, semesters).
class Admin::ProgramSetupsController < Admin::BaseController
  def show
    @tab = normalize_tab(params[:tab])

    @program_tracks = ProgramTrack.ordered
    @new_program_track = ProgramTrack.new(active: true)

    @majors = Major.order(Arel.sql("LOWER(name) ASC"))
    @new_major = Major.new

    @program_years = ProgramYear.data_source_ready? ? ProgramYear.active.ordered : []
    @new_program_year = ProgramYear.new(active: true)

    @program_semesters = ProgramSemester.order(Arel.sql("current DESC"), Arel.sql("LOWER(name) ASC"))
    @current_program_semester = ProgramSemester.current
    @new_program_semester = ProgramSemester.new

    load_target_levels_state if @tab == "targets"
  end

  private

  def normalize_tab(value)
    allowed = %w[tracks majors years semesters targets]
    tab = value.to_s.strip
    allowed.include?(tab) ? tab : "tracks"
  end

  def load_target_levels_state
    @post_save_warning = session.delete(:target_levels_post_save_warning)
    @semesters = ProgramSemester.order(Arel.sql("current DESC"), Arel.sql("LOWER(name) ASC"))
    @tracks = Student.tracks.values
    class_years = Student.where.not(program_year: nil).distinct.order(:program_year).pluck(:program_year)
    @class_of_options = [["All classes", ""]] + class_years.map { |year| ["Class of #{year}", year.to_s] }

    requested_semester_id = params[:program_semester_id].to_s.presence
    @selected_semester_id = requested_semester_id&.to_i
    @selected_track = params[:track].to_s.presence

    year = params[:class_of].to_s.strip
    @selected_class_of = year.present? ? year.to_i : nil

    load_targets
    @submitted_students_count = submitted_students_count_for_selected_context
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
      submitted_scope = submitted_scope.where(students: { program_year: @selected_class_of })
    end

    submitted_scope.select(:student_id).distinct.count
  end
end
