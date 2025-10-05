json.extract! question, :id, :question_id, :category_id, :question_order, :question_type, :answer_options, :created_at, :updated_at
json.url question_url(question, format: :json)
