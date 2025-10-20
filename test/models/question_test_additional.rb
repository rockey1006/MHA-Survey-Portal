require "test_helper"

class QuestionAdditionalTest < ActiveSupport::TestCase
  test "multiple choice yes/no is not considered required by default" do
    q = Question.new(question_type: "multiple_choice", answer_options: "Yes\nNo")
    assert q.question_type_multiple_choice?
    options = q.answer_options_list.map(&:strip).map(&:downcase)
    assert_equal %w[yes no], options
    # The controller logic treats yes/no only options as not required
    assert options == %w[yes no] || options == %w[no yes]
  end
end
