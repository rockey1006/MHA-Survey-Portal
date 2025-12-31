module Advisors
  # Legacy controller kept for safety.
  # /advisors/surveys routes are redirected to the shared Assignments::Surveys area.
  class SurveysController < BaseController
    def index
      redirect_to assignments_surveys_path
    end

    def show
      redirect_to assignments_survey_path(params[:id])
    end
  end
end
