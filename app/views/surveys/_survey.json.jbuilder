json.extract! survey, :id, :survey_id, :assigned_date, :completion_date, :approval_date, :created_at, :updated_at
json.url survey_url(survey, format: :json)
