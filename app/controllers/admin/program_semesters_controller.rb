# Manages the list of available program semesters from the admin panel.
# Allows admins to add upcoming terms, delete obsolete ones, and mark which
# semester should be considered "current" throughout the app.
class Admin::ProgramSemestersController < Admin::BaseController
  before_action :set_program_semester, only: %i[destroy make_current]

  # POST /admin/program_semesters
  def create
    @program_semester = ProgramSemester.new(program_semester_params)

    if @program_semester.save
      redirect_back_to_manager notice: "Semester '#{@program_semester.name}' created."
    else
      redirect_back_to_manager alert: @program_semester.errors.full_messages.to_sentence
    end
  end

  # DELETE /admin/program_semesters/:id
  def destroy
    name = @program_semester.name

    if @program_semester.destroy
      redirect_back_to_manager notice: "Semester '#{name}' deleted."
    else
      redirect_back_to_manager alert: @program_semester.errors.full_messages.to_sentence
    end
  end

  # PATCH /admin/program_semesters/:id/make_current
  def make_current
    if @program_semester.update(current: true)
      redirect_back_to_manager notice: "#{@program_semester.name} is now the current semester."
    else
      redirect_back_to_manager alert: @program_semester.errors.full_messages.to_sentence
    end
  end

  private

  def program_semester_params
    params.require(:program_semester).permit(:name, :current)
  end

  def set_program_semester
    @program_semester = ProgramSemester.find(params[:id])
  end

  def redirect_back_to_manager(**flash)
    redirect_to admin_surveys_path(anchor: "semester-manager"), **flash
  end
end
