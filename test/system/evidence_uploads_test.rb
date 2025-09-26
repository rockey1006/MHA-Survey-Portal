require "application_system_test_case"

class EvidenceUploadsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @evidence_upload = evidence_uploads(:one)
    sign_in admins(:one)
  end

  test "visiting the index" do
    visit evidence_uploads_url
    assert_selector "h1", text: "Evidence uploads"
  end

  test "should create evidence upload" do
    visit evidence_uploads_url
    click_on "New evidence upload"

    fill_in "Competencyresponse", with: @evidence_upload.competencyresponse_id
    fill_in "Evidenceupload", with: @evidence_upload.evidenceupload_id
    fill_in "Link", with: @evidence_upload.link
    fill_in "Questionresponse", with: @evidence_upload.questionresponse_id
    click_on "Create Evidence upload"

    assert_text "Evidence upload was successfully created"
    click_on "Back"
  end

  test "should update Evidence upload" do
    visit evidence_upload_url(@evidence_upload)
    click_on "Edit this evidence upload", match: :first

    fill_in "Competencyresponse", with: @evidence_upload.competencyresponse_id
    fill_in "Evidenceupload", with: @evidence_upload.evidenceupload_id
    fill_in "Link", with: @evidence_upload.link
    fill_in "Questionresponse", with: @evidence_upload.questionresponse_id
    click_on "Update Evidence upload"

    assert_text "Evidence upload was successfully updated"
    click_on "Back"
  end

  test "should destroy Evidence upload" do
    visit evidence_upload_url(@evidence_upload)
    click_on "Destroy this evidence upload", match: :first

    assert_text "Evidence upload was successfully destroyed"
  end
end
