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
    assert(body.include?("invalid") || body.include?("invalid google drive") || body.include?("invalid link"))
  end
end
