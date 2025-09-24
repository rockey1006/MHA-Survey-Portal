json.extract! survey_response, :id, :surveyresponse_id, :student_id, :advisor_id, :survey_id, :semester, :status, :created_at, :updated_at
json.url survey_response_url(survey_response, format: :json)
