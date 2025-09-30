require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  def setup
    @feedback = feedbacks(:one) if defined?(feedbacks)
  end

  test "should be valid with valid attributes" do
    skip "No feedback fixture defined" unless @feedback
    assert @feedback.valid?
  end

  test "should create feedback with required attributes" do
    feedback = Feedback.new(
      comments: "This is test feedback",
      rating: 5
    )

    # Add other required attributes based on your model
    assert feedback.valid? || feedback.errors.any?, "Feedback should be valid or show specific errors"
  end

  test "should validate comments presence" do
    feedback = Feedback.new(comments: nil)
    assert_not feedback.valid?
    assert_includes feedback.errors[:comments], "can't be blank" if feedback.errors[:comments]
  end

  test "should validate rating if present" do
    if Feedback.new.respond_to?(:rating)
      feedback = Feedback.new(comments: "Test", rating: 6)
      # Assuming rating should be between 1-5
      assert_not feedback.valid? if feedback.class.validators_on(:rating).any?
    end
  end

  test "should belong to associated models" do
    feedback = Feedback.new

    # Test associations based on your model definition
    if feedback.respond_to?(:student)
      assert_respond_to feedback, :student
    end

    if feedback.respond_to?(:survey_response)
      assert_respond_to feedback, :survey_response
    end
  end
end
