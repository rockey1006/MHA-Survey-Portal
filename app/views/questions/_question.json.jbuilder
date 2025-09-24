json.extract! question, :id, :question_id, :competency_id, :question_order, :question_type, :created_at, :updated_at
json.url question_url(question, format: :json)
