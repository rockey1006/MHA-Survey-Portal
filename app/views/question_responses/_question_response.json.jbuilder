json.extract! question_response, :id, :student_id, :advisor_id, :question_id, :answer, :created_at, :updated_at
json.url question_response_url(question_response, format: :json)
