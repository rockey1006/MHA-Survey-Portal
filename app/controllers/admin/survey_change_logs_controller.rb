class Admin::SurveyChangeLogsController < Admin::BaseController
  def index
    @action_filter = params[:action_type].presence
    scope = SurveyChangeLog.includes(:survey, :admin).order(created_at: :desc)
    scope = scope.where(action: @action_filter) if @action_filter.present?

    @logs = scope.limit(200)
    @available_actions = SurveyChangeLog::ACTIONS
  end
end
