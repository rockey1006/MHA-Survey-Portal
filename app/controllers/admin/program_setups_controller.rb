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
  end

  private

  def normalize_tab(value)
    allowed = %w[tracks majors years semesters]
    tab = value.to_s.strip
    allowed.include?(tab) ? tab : "tracks"
  end
end
