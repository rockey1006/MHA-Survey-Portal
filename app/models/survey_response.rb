class SurveyResponse < ApplicationRecord
    enum status: { not_started: 0, in_progress: 1, submitted: 2, under_review: 3, approved: 4 }
end
