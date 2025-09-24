json.extract! feedback, :id, :feedback_id, :advisor_id, :competency_id, :rating, :comments, :created_at, :updated_at
json.url feedback_url(feedback, format: :json)
