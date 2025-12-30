require "test_helper"

class QuestionAnswerOptionsParsingTest < ActiveSupport::TestCase
  test "answer_option_pairs parses json string arrays" do
    q = Question.new(question_type: "multiple_choice", answer_options: %w[Yes No].to_json)
    assert_equal [ [ "Yes", "Yes" ], [ "No", "No" ] ], q.answer_option_pairs
  end

  test "answer_option_pairs parses json [label,value] pairs" do
    q = Question.new(
      question_type: "dropdown",
      answer_options: [ [ "Beginner (1)", "1" ], [ "Mastery (5)", "5" ] ].to_json
    )
    assert_equal [ [ "Beginner (1)", "1" ], [ "Mastery (5)", "5" ] ], q.answer_option_pairs
  end

  test "answer_option_pairs parses json objects" do
    q = Question.new(
      question_type: "dropdown",
      answer_options: [ { label: "Other — Please describe", value: "0", requires_text: true } ].to_json
    )
    assert_equal [ [ "Other — Please describe", "0" ] ], q.answer_option_pairs
  end

  test "answer_options_list parses newline-separated options" do
    q = Question.new(
      question_type: "multiple_choice",
      answer_options: "Yes\nNo\nMaybe"
    )
    assert_equal [ "Yes", "No", "Maybe" ], q.answer_options_list
    assert_equal [ [ "Yes", "Yes" ], [ "No", "No" ], [ "Maybe", "Maybe" ] ], q.answer_option_pairs
  end

  test "answer_options_list parses comma-separated options" do
    q = Question.new(
      question_type: "multiple_choice",
      answer_options: "Yes, No, Maybe"
    )
    assert_equal [ "Yes", "No", "Maybe" ], q.answer_options_list
  end
end
