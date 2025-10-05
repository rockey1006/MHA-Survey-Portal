json.extract! feedback, :id, :feedback_id, :advisor_id, :category_id, :surveyresponse_id, :score, :comments, :created_at, :updated_at
json.url feedback_url(feedback, format: :json)
