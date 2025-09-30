require "test_helper"

class CompetencyTest < ActiveSupport::TestCase
  def setup
    @competency = competencies(:one)
  end

  test "should be valid with valid attributes" do
    assert @competency.valid?
  end

  test "should belong to survey" do
    assert_respond_to @competency, :survey
  end

  test "should allow optional survey association" do
    competency = Competency.new(name: "Test Competency", description: "Test Description")
    assert competency.valid?
  end

  test "should have questions association" do
    assert_respond_to @competency, :questions
  end

  test "should have competency_responses association" do
    assert_respond_to @competency, :competency_responses
  end

  test "should destroy dependent questions when competency is destroyed" do
    competency = Competency.create!(name: "Test Competency", description: "Test Description")
    question = competency.questions.create!(question: "Test Question", question_type: "text")

    assert_difference("Question.count", -1) do
      competency.destroy
    end
  end

  test "should destroy dependent competency_responses when competency is destroyed" do
    competency = Competency.create!(name: "Test Competency", description: "Test Description")

    initial_count = Competency.count
    competency.destroy
    assert_equal initial_count - 1, Competency.count
  end
end
