require "test_helper"

class QuestionPromptFormatTest < ActiveSupport::TestCase
  test "rich_text_prompt? is true when format is explicitly rich_text" do
    question = Question.new(prompt_format: "rich_text", question_text: "Plain prompt")

    assert question.rich_text_prompt?
  end

  test "rich_text_prompt? is true when format is blank and prompt contains supported html tags" do
    question = Question.new(
      prompt_format: nil,
      question_text: "How many <strong>hours per week</strong> do you work on <u>average</u>?"
    )

    assert question.rich_text_prompt?
  end

  test "rich_text_prompt? remains false when format is plain_text even if html-like tags are present" do
    question = Question.new(
      prompt_format: "plain_text",
      question_text: "How many <strong>hours per week</strong> do you work?"
    )

    assert_not question.rich_text_prompt?
  end
end
