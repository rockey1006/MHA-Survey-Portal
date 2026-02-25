# frozen_string_literal: true

require "test_helper"

class EvidenceControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @student = users(:student)
    @valid_sites_url = "https://sites.google.com/tamu.edu/sample-site/home"
  end

  test "check_access requires authentication" do
    get evidence_check_access_path(url: @valid_sites_url), as: :json

    assert_response :unauthorized
  end

  test "check_access accepts valid google sites url format" do
    sign_in @student
    stub_request(:head, @valid_sites_url).to_return(status: 200)

    get evidence_check_access_path(url: @valid_sites_url), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response["ok"]
    assert_equal true, json_response["accessible"]
    assert_equal 200, json_response["status"]
    assert_equal "ok", json_response["reason"]
  end

  test "check_access rejects google drive url format" do
    sign_in @student

    get evidence_check_access_path(url: "https://drive.google.com/file/d/123/view"), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal false, json_response["ok"]
    assert_equal false, json_response["accessible"]
    assert_nil json_response["status"]
    assert_equal "invalid_url", json_response["reason"]
  end

  test "check_access rejects google docs url format" do
    sign_in @student

    get evidence_check_access_path(url: "https://docs.google.com/document/d/abc/edit"), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "invalid_url", json_response["reason"]
  end

  test "check_access rejects non-google url" do
    sign_in @student

    get evidence_check_access_path(url: "https://example.com/portfolio"), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "invalid_url", json_response["reason"]
  end

  test "check_access returns network_error when fetch fails for valid sites url" do
    sign_in @student
    stub_request(:head, @valid_sites_url).to_raise(StandardError.new("boom"))

    get evidence_check_access_path(url: @valid_sites_url), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal false, json_response["ok"]
    assert_equal false, json_response["accessible"]
    assert_nil json_response["status"]
    assert_equal "network_error", json_response["reason"]
  end

  test "fetch_with_redirects follows redirects and falls back to GET" do
    controller = EvidenceController.new
    start_url = "https://sites.google.com/tamu.edu/start"
    redirected = "https://sites.google.com/tamu.edu/final"

    stub_request(:head, start_url).to_return(status: 302, headers: { "Location" => redirected })
    stub_request(:head, redirected).to_return(status: 405)
    stub_request(:get, redirected).to_return(status: 200)

    response = controller.send(:fetch_with_redirects, start_url)
    assert_equal "200", response.code
  end
end
