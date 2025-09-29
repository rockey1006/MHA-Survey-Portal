module Advisors
  class SurveysController < ApplicationController
    MOCK_SURVEYS = [
      { id: 1, title: "Health & Wellness Survey", description: "Semester check-in on student health." },
      { id: 2, title: "Academic Progress Survey", description: "Evaluate student course performance." },
      { id: 3, title: "Career Goals Survey", description: "Explore future career planning." }
    ]

    MOCK_STUDENTS = [
      { id: 1, first_name: "Alice", last_name: "Nguyen" },
      { id: 2, first_name: "Brian", last_name: "Smith" },
      { id: 3, first_name: "Cara", last_name: "Lee" },
      { id: 4, first_name: "Daniel", last_name: "Patel" }
    ]

    # List all surveys (use real Survey records)
    def index
      @surveys = Survey.includes(:questions).all
    end

    # Show one survey and allow assignment (use real Survey and Student records)
    def show
      @survey = Survey.find(params[:id])
      @survey_number = Survey.order(:id).pluck(:id).index(@survey.id) + 1
      @students = Student.all
    end

    # Assign survey to student (mock only)
    def assign
      @survey_id = params[:id].to_i
      @student_id = params[:student_id].to_i

      flash[:notice] = "Survey ##{@survey_id} assigned to student ##{@student_id}!"
      redirect_to advisors_surveys_path
    end
  end
end
