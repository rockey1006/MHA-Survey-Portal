# frozen_string_literal: true

require "test_helper"

class EvidenceControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:admin)
    @advisor = users(:advisor)
    @student = users(:student)
    @valid_drive_url = "https://drive.google.com/file/d/1234567890/view"
    @valid_docs_url = "https://docs.google.com/document/d/1234567890/edit"
  end

  # Authentication tests
  test "check_access requires authentication" do
    get evidence_check_access_path(url: @valid_drive_url), as: :json

    assert_response :unauthorized
  end

  test "check_access allows authenticated admin" do
    sign_in @admin

    get evidence_check_access_path(url: @valid_drive_url), as: :json

    assert_response :success
  end

  test "check_access allows authenticated advisor" do
    sign_in @advisor

    get evidence_check_access_path(url: @valid_drive_url), as: :json

    assert_response :success
  end

  test "check_access allows authenticated student" do
    sign_in @student

    get evidence_check_access_path(url: @valid_drive_url), as: :json

    assert_response :success
  end

  # URL validation tests
  test "check_access rejects invalid url" do
    sign_in @student

    get evidence_check_access_path(url: "https://example.com/file.pdf"), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert_equal false, json_response["ok"]
    assert_equal false, json_response["accessible"]
    assert_nil json_response["status"]
    assert_equal "invalid_url", json_response["reason"]
  end

  test "check_access rejects non-google-drive url" do
    sign_in @student

    get evidence_check_access_path(url: "https://dropbox.com/file/123"), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert_equal false, json_response["ok"]
    assert_equal "invalid_url", json_response["reason"]
  end

  test "check_access rejects empty url" do
    sign_in @student

    get evidence_check_access_path(url: ""), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert_equal false, json_response["ok"]
    assert_equal "invalid_url", json_response["reason"]
  end

  test "check_access rejects missing url parameter" do
    sign_in @student

    get evidence_check_access_path, as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert_equal false, json_response["ok"]
    assert_equal "invalid_url", json_response["reason"]
  end

  # Valid Google Drive URL formats
  test "check_access validates drive.google.com file url format" do
    sign_in @student
    url = "https://drive.google.com/file/d/1234567890/view"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert json_response.key?("ok")
    assert json_response.key?("accessible")
    assert json_response.key?("status")
    assert json_response.key?("reason")
  end

  test "check_access validates drive folder url format" do
    sign_in @student
    url = "https://drive.google.com/drive/folders/1234567890"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  test "check_access validates google docs url format" do
    sign_in @student

    get evidence_check_access_path(url: @valid_docs_url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  test "check_access validates spreadsheet url format" do
    sign_in @student
    url = "https://docs.google.com/spreadsheets/d/1234567890/edit"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  test "check_access validates forms url format" do
    sign_in @student
    url = "https://docs.google.com/forms/d/1234567890/viewform"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  test "check_access validates drive open url format" do
    sign_in @student
    url = "https://drive.google.com/open?id=1234567890"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  # JSON response format
  test "check_access returns JSON format" do
    sign_in @student

    get evidence_check_access_path(url: @valid_drive_url), as: :json

    assert_response :success
    assert_equal "application/json; charset=utf-8", @response.content_type
  end

  test "check_access response has all required fields" do
    sign_in @student

    get evidence_check_access_path(url: "invalid"), as: :json

    json_response = JSON.parse(@response.body)
    assert json_response.key?("ok")
    assert json_response.key?("accessible")
    assert json_response.key?("status")
    assert json_response.key?("reason")
  end

  # HTTP vs HTTPS
  test "check_access validates https urls" do
    sign_in @student
    url = "https://drive.google.com/file/d/1234567890/view"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  test "check_access validates http urls" do
    sign_in @student
    url = "http://drive.google.com/file/d/1234567890/view"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  # Edge cases
  test "check_access handles url with special characters" do
    sign_in @student
    url = "https://drive.google.com/file/d/ABC-123_xyz/view?usp=sharing"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  test "check_access handles url with query parameters" do
    sign_in @student
    url = "https://drive.google.com/file/d/1234567890/view?usp=sharing&resourcekey=abc123"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  # Multiple requests
  test "check_access can be called multiple times" do
    sign_in @student

    3.times do
      get evidence_check_access_path(url: @valid_drive_url), as: :json
      assert_response :success
    end
  end

  # Different user roles
  test "check_access works for all user roles" do
    [ @student, @advisor, @admin ].each do |user|
      sign_in user
      get evidence_check_access_path(url: @valid_drive_url), as: :json
      
      assert_response :success
      json_response = JSON.parse(@response.body)
      assert json_response.key?("ok")
      
      sign_out user
    end
  end

  # Invalid URL patterns
  test "check_access rejects non-drive domains" do
    sign_in @student
    invalid_urls = [
      "https://www.google.com/search?q=test",
      "https://gmail.com/mail",
      "https://youtube.com/watch?v=123"
    ]

    invalid_urls.each do |url|
      get evidence_check_access_path(url: url), as: :json
      
      json_response = JSON.parse(@response.body)
      assert_equal false, json_response["ok"]
      assert_equal "invalid_url", json_response["reason"]
    end
  end

  # Valid URL patterns
  test "check_access accepts all valid Google Drive URL patterns" do
    sign_in @student
    valid_urls = [
      "https://drive.google.com/file/d/123/view",
      "https://drive.google.com/drive/folders/abc",
      "https://docs.google.com/document/d/xyz/edit",
      "https://docs.google.com/spreadsheets/d/789/edit"
    ]

    valid_urls.each do |url|
      get evidence_check_access_path(url: url), as: :json
      
      json_response = JSON.parse(@response.body)
      refute_equal "invalid_url", json_response["reason"]
    end
  end

  # Parameter handling
  test "check_access handles nil url parameter" do
    sign_in @student

    get evidence_check_access_path, as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert_equal "invalid_url", json_response["reason"]
  end

  test "check_access handles blank url parameter" do
    sign_in @student

    get evidence_check_access_path(url: "   "), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert_equal "invalid_url", json_response["reason"]
  end

  # Response consistency
  test "check_access returns consistent response structure" do
    sign_in @student

    get evidence_check_access_path(url: "invalid"), as: :json
    invalid_response = JSON.parse(@response.body)

    get evidence_check_access_path(url: @valid_drive_url), as: :json
    valid_response = JSON.parse(@response.body)

    assert_equal invalid_response.keys.sort, valid_response.keys.sort
  end

  # Case sensitivity
  test "check_access is case-insensitive for domain" do
    sign_in @student
    url = "https://DRIVE.GOOGLE.COM/file/d/1234567890/view"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  # Boolean values verification
  test "check_access returns boolean values for ok and accessible" do
    sign_in @student

    get evidence_check_access_path(url: "invalid"), as: :json

    json_response = JSON.parse(@response.body)
    assert [ true, false ].include?(json_response["ok"])
    assert [ true, false ].include?(json_response["accessible"])
  end

  # String values verification
  test "check_access returns string value for reason" do
    sign_in @student

    get evidence_check_access_path(url: "invalid"), as: :json

    json_response = JSON.parse(@response.body)
    assert_kind_of String, json_response["reason"]
  end

  # Status code verification  
  test "check_access returns nil status for invalid url" do
    sign_in @student

    get evidence_check_access_path(url: "invalid"), as: :json

    json_response = JSON.parse(@response.body)
    assert_nil json_response["status"]
  end

  # Complex URL patterns
  test "check_access accepts Google Docs with long IDs" do
    sign_in @student
    url = "https://docs.google.com/document/d/1234567890abcdefghijklmnopqrstuvwxyz/edit?usp=sharing"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
    json_response = JSON.parse(@response.body)
    refute_equal "invalid_url", json_response["reason"]
  end

  # Path variations
  test "check_access accepts various Google Drive path formats" do
    sign_in @student
    
    paths = [
      "/file/d/123/view",
      "/drive/folders/abc",
      "/document/d/xyz/edit",
      "/spreadsheets/d/789/edit",
      "/forms/d/def/viewform",
      "/open?id=ghi"
    ]

    paths.each do |path|
      url = "https://drive.google.com#{path}"
      get evidence_check_access_path(url: url), as: :json
      
      json_response = JSON.parse(@response.body)
      refute_equal "invalid_url", json_response["reason"]
    end
  end

  # Unauthenticated requests
  test "check_access rejects unauthenticated requests" do
    get evidence_check_access_path(url: @valid_drive_url), as: :json

    assert_response :unauthorized
  end

  # URL encoding
  test "check_access handles url-encoded characters" do
    sign_in @student
    url = "https://drive.google.com/file/d/123%20456/view"

    get evidence_check_access_path(url: url), as: :json

    assert_response :success
  end

  # Response value types
  test "check_access response values have correct types" do
    sign_in @student

    get evidence_check_access_path(url: "invalid"), as: :json

    json_response = JSON.parse(@response.body)
    assert [ TrueClass, FalseClass ].include?(json_response["ok"].class)
    assert [ TrueClass, FalseClass ].include?(json_response["accessible"].class)
    assert [ NilClass, Integer ].include?(json_response["status"].class)
    assert_kind_of String, json_response["reason"]
  end
end
