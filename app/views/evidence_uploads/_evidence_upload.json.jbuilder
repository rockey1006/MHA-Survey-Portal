json.extract! evidence_upload, :id, :evidenceupload_id, :questionresponse_id, :competencyresponse_id, :file_type, :created_at, :updated_at
json.url evidence_upload_url(evidence_upload, format: :json)
