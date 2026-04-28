# frozen_string_literal: true

class Admin::CourseGradeReleaseDatesController < Admin::BaseController
  def index
    @semesters = ProgramSemester.ordered
    @release_dates = CourseGradeReleaseDate.all.index_by(&:program_semester_id)

    # Count surveys per semester
    @survey_counts = Survey.joins(:program_semester)
                           .group(:program_semester_id)
                           .count
  end

  def edit
    @release_date = CourseGradeReleaseDate.find(params[:id])
    @semester = @release_date.program_semester
  end

  def update
    @release_date = CourseGradeReleaseDate.find(params[:id])
    if @release_date.update(release_date_params)
      redirect_to admin_course_grade_release_dates_path, notice: "Course grade release date updated."
    else
      render :edit
    end
  end

  def new
    @semester = ProgramSemester.find(params[:semester_id])
    @release_date = CourseGradeReleaseDate.new(program_semester: @semester)
  end

  def create
    @semester = ProgramSemester.find(release_date_params[:program_semester_id])
    @release_date = CourseGradeReleaseDate.new(release_date_params)

    if @release_date.save
      redirect_to admin_course_grade_release_dates_path, notice: "Course grade release date created."
    else
      render :new
    end
  end

  def destroy
    @release_date = CourseGradeReleaseDate.find(params[:id])
    @release_date.destroy
    redirect_to admin_course_grade_release_dates_path, notice: "Course grade release date cleared."
  end

  private

  def release_date_params
    params.require(:course_grade_release_date).permit(:program_semester_id, :release_date)
  end
end
