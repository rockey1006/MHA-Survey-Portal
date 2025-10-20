json.extract! feedback, :id, :student_id, :advisor_id, :category_id, :survey_id, :average_score, :comments, :created_at, :updated_at
json.url feedback_url(feedback, format: :json)
