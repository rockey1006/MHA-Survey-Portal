require "test_helper"

class SurveysControllerValidationTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  tests SurveysController

  setup do
    @user = users(:student)
    sign_in @user
    @student = students(:student)
    @survey = surveys(:fall_2025)
  end

  test "evidence_accessible returns invalid for malformed uri" do
    accessible, reason = @controller.send(:evidence_accessible?, "not a url")
    assert_equal false, accessible
    assert_equal :invalid, reason
  end

  test "evidence_accessible returns invalid for non-https urls" do
    accessible, reason = @controller.send(:evidence_accessible?, "http://docs.google.com/document/d/abc123/edit")
    assert_equal false, accessible
    assert_equal :invalid, reason
  end

  test "evidence_accessible returns invalid for non-allowlisted hosts" do
    accessible, reason = @controller.send(:evidence_accessible?, "https://example.com/file")
    assert_equal false, accessible
    assert_equal :invalid, reason
  end

  test "evidence_accessible accepts public docs export endpoint" do
    export_url = "https://docs.google.com/document/d/abc123/export?format=txt"
    stub_request(:get, export_url).to_return(status: 200, body: "ok")

    accessible, reason = @controller.send(:evidence_accessible?, "https://docs.google.com/document/d/abc123/edit")
    assert_equal true, accessible
    assert_equal :ok, reason
  end

  test "evidence_accessible returns timeout when docs export times out" do
    export_url = "https://docs.google.com/document/d/timeout123/export?format=txt"
    stub_request(:get, export_url).to_timeout

    accessible, reason = @controller.send(:evidence_accessible?, "https://docs.google.com/document/d/timeout123/edit")
    assert_equal false, accessible
    assert_equal :timeout, reason
  end

  test "evidence_accessible flags forbidden when HEAD succeeds but sniff indicates sign-in" do
    url = "https://drive.google.com/file/d/abc123/view"
    stub_request(:head, url).to_return(status: 200)
    stub_request(:get, url).to_return(status: 200, body: "Sign in to continue")

    accessible, reason = @controller.send(:evidence_accessible?, url)
    assert_equal false, accessible
    assert_equal :forbidden, reason
  end

  test "evidence_accessible handles HEAD not allowed by falling back to GET" do
    url = "https://drive.google.com/file/d/method_not_allowed/view"
    stub_request(:head, url).to_return(status: 405)
    # Minimal range GET returns 200, then sniff GET returns forbidden marker
    stub_request(:get, url).to_return(status: 200, body: "Request access")

    accessible, reason = @controller.send(:evidence_accessible?, url)
    assert_equal false, accessible
    assert_equal :forbidden, reason
  end

  test "evidence_accessible rejects redirects to non-allowlisted hosts" do
    url = "https://drive.google.com/file/d/redir/view"
    stub_request(:head, url).to_return(status: 302, headers: { "Location" => "https://accounts.google.com/signin" })

    accessible, reason = @controller.send(:evidence_accessible?, url)
    assert_equal false, accessible
    assert_equal :forbidden, reason
  end

  test "evidence_accessible returns too_many_redirects after redirect limit" do
    url1 = "https://drive.google.com/file/d/r1/view"
    url2 = "https://drive.google.com/file/d/r2/view"
    url3 = "https://drive.google.com/file/d/r3/view"
    url4 = "https://drive.google.com/file/d/r4/view"
    url5 = "https://drive.google.com/file/d/r5/view"

    stub_request(:head, url1).to_return(status: 302, headers: { "Location" => url2 })
    stub_request(:head, url2).to_return(status: 302, headers: { "Location" => url3 })
    stub_request(:head, url3).to_return(status: 302, headers: { "Location" => url4 })
    stub_request(:head, url4).to_return(status: 302, headers: { "Location" => url5 })

    accessible, reason = @controller.send(:evidence_accessible?, url1)
    assert_equal false, accessible
    assert_equal :too_many_redirects, reason
  end

  test "evidence_accessible returns error for redirects without location" do
    url = "https://drive.google.com/file/d/no_location/view"
    stub_request(:head, url).to_return(status: 302)

    accessible, reason = @controller.send(:evidence_accessible?, url)
    assert_equal false, accessible
    assert_equal :error, reason
  end

  test "evidence_accessible returns not_found for 404" do
    url = "https://drive.google.com/file/d/missing/view"
    stub_request(:head, url).to_return(status: 404)

    accessible, reason = @controller.send(:evidence_accessible?, url)
    assert_equal false, accessible
    assert_equal :not_found, reason
  end

  test "evidence_accessible returns error on unexpected exceptions" do
    url = "https://drive.google.com/file/d/explode/view"
    stub_request(:head, url).to_raise(StandardError.new("boom"))

    accessible, reason = @controller.send(:evidence_accessible?, url)
    assert_equal false, accessible
    assert_equal :error, reason
  end

  test "submit re-renders show with 422 when required answers missing" do
    # post with empty answers
    post :submit, params: { id: @survey.id, answers: {} }
    assert_response :unprocessable_entity
    # Ensure the response body contains form content (rendered show)
    assert_includes @response.body, "<form"
  end

  test "submit detects invalid evidence links and re-renders" do
    # craft answers with invalid evidence for any evidence question fixture
    # ensure there is at least one evidence type question to trigger validation
    ev = @survey.questions.detect { |qq| qq.question_type == "evidence" }
    unless ev
      cat = @survey.categories.first
      ev = Question.create!(category: cat, question_text: "Evidence temp", question_order: 9999, question_type: "evidence", is_required: false)
    end
    @survey.reload
    answers = {}
    @survey.questions.each do |q|
      answers[q.id.to_s] = (q.id == ev.id) ? "https://not-drive.example.com/file" : "Ok"
    end
    post :submit, params: { id: @survey.id, answers: answers }
    assert_response :unprocessable_entity
    body = @response.body.to_s.downcase
    assert(body.include?("invalid") || body.include?("invalid google") || body.include?("invalid link"))
  end
end
