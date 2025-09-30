require "test_helper"

class QuestionResponseTest < ActiveSupport::TestCase
  def setup
    @question_response = question_responses(:one)
  end

  test "should be valid with valid attributes" do
    assert @question_response.valid?
  end

  test "should belong to question" do
    assert_respond_to @question_response, :question
  end

  test "should store response answer" do
    @question_response.answer = "This is a test response"
    assert_equal "This is a test response", @question_response.answer
  end

  test "should handle different response types" do
    # Test text response
    @question_response.answer = "Long text response here"
    assert @question_response.valid?

    # Test select/radio response
    @question_response.answer = "Option 1"
    assert @question_response.valid?

    # Test checkbox response (could be JSON array or comma-separated)
    @question_response.answer = "Option 1,Option 2"
    assert @question_response.valid?
  end

  test "should allow empty answer" do
    @question_response.answer = ""
    assert @question_response.valid?

    @question_response.answer = nil
    assert @question_response.valid?
  end
end
