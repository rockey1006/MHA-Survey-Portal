require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  def setup
    @question = questions(:one)
  end

  test "should be valid with valid attributes" do
    assert @question.valid?
  end

  test "should belong to competency" do
    assert_respond_to @question, :competency
  end

  test "should allow optional competency association" do
    question = Question.new(question: "Test Question", question_type: "text")
    assert question.valid?
  end

  test "should have question_responses association" do
    assert_respond_to @question, :question_responses
  end

  test "should destroy dependent question_responses when question is destroyed" do
    question = Question.create!(question: "Test Question", question_type: "text")

    initial_count = Question.count
    question.destroy
    assert_equal initial_count - 1, Question.count
  end

  test "should accept valid question types" do
    valid_types = %w[text select radio checkbox]

    valid_types.each do |type|
      @question.question_type = type
      assert @question.valid?, "Question should be valid with question_type: #{type}"
    end
  end

  test "should handle answer_options for select and radio questions" do
    @question.question_type = "select"
    @question.answer_options = [ "Option 1", "Option 2", "Option 3" ]
    assert @question.valid?

    @question.question_type = "radio"
    @question.answer_options = [ "Yes", "No", "Maybe" ]
    assert @question.valid?
  end

  test "text questions should not require answer_options" do
    @question.question_type = "text"
    @question.answer_options = nil
    assert @question.valid?
  end
end
