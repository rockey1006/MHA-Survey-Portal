require "test_helper"

class EvidenceUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @evidence_upload = evidence_uploads(:one)
  end

  test "should get index" do
    get evidence_uploads_url
    assert_response :success
  end

  test "should get new" do
    get new_evidence_upload_url
    assert_response :success
  end

  test "should create evidence_upload" do
    assert_difference("EvidenceUpload.count") do
      post evidence_uploads_url, params: { evidence_upload: { competencyresponse_id: @evidence_upload.competencyresponse_id, evidenceupload_id: @evidence_upload.evidenceupload_id, file_type: @evidence_upload.file_type, questionresponse_id: @evidence_upload.questionresponse_id } }
    end

    assert_redirected_to evidence_upload_url(EvidenceUpload.last)
  end

  test "should show evidence_upload" do
    get evidence_upload_url(@evidence_upload)
    assert_response :success
  end

  test "should get edit" do
    get edit_evidence_upload_url(@evidence_upload)
    assert_response :success
  end

  test "should update evidence_upload" do
    patch evidence_upload_url(@evidence_upload), params: { evidence_upload: { competencyresponse_id: @evidence_upload.competencyresponse_id, evidenceupload_id: @evidence_upload.evidenceupload_id, file_type: @evidence_upload.file_type, questionresponse_id: @evidence_upload.questionresponse_id } }
    assert_redirected_to evidence_upload_url(@evidence_upload)
  end

  test "should destroy evidence_upload" do
    assert_difference("EvidenceUpload.count", -1) do
      delete evidence_upload_url(@evidence_upload)
    end

    assert_redirected_to evidence_uploads_url
  end
end
