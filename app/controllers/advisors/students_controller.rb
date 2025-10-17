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
  end
end
