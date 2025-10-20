module Advisors
  # Legacy controller maintained temporarily to ensure any stale links
  # or bookmarks redirect to the new shared student records page.
  class StudentsController < BaseController
    # Redirects legacy routes to the consolidated student records dashboard.
    #
    # @return [void]
    def index
      redirect_to student_records_path
    end

    def show
      @student = Student.find(params[:id])
    end

    def update
      @student = Student.find(params[:id])
      if @student.update(student_params)
        redirect_to advisors_student_path(@student), notice: "Track updated to #{@student.track.titleize}."
      else
        flash.now[:alert] = @student.errors.full_messages.to_sentence
        render :show, status: :unprocessable_entity
      end
    end

    private

    def student_params
      params.require(:student).permit(:track)
    end
  end
end
