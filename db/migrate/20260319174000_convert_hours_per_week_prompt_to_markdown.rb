class ConvertHoursPerWeekPromptToMarkdown < ActiveRecord::Migration[8.0]
  PLAIN_TEXT = "How many hours per week do you work on average?".freeze
  HTML_TEXT = "How many <strong>hours per week</strong> do you work on <u>average</u>?".freeze
  MARKDOWN_TEXT = "How many **hours per week** do you work on _average_?".freeze

  def up
    return unless table_exists?(:questions)

    execute <<~SQL
      UPDATE questions
      SET question_text = #{connection.quote(MARKDOWN_TEXT)},
          configuration = COALESCE(configuration, '{}'::jsonb) || '{"prompt_format":"rich_text"}'::jsonb,
          updated_at = CURRENT_TIMESTAMP
      WHERE question_text IN (
        #{connection.quote(PLAIN_TEXT)},
        #{connection.quote(HTML_TEXT)}
      );
    SQL
  end

  def down
    execute <<~SQL
      UPDATE questions
      SET question_text = #{connection.quote(HTML_TEXT)},
          updated_at = CURRENT_TIMESTAMP
      WHERE question_text = #{connection.quote(MARKDOWN_TEXT)};
    SQL
  end
end
