# Presents recent survey change log entries to admins with optional filters.
class Admin::SurveyChangeLogsController < Admin::BaseController
  # Lists change log entries, optionally filtered by action type.
  #
  # @return [void]
  def index
    @action_filter = params[:action_type].presence
    scope = SurveyChangeLog.includes(:survey, :admin).order(created_at: :desc)
    scope = scope.where(action: @action_filter) if @action_filter.present?

    @logs = scope.limit(200)
    @available_actions = SurveyChangeLog::ACTIONS
  end
end
