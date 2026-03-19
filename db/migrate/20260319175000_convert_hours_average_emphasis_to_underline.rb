class ConvertHoursAverageEmphasisToUnderline < ActiveRecord::Migration[8.0]
  ITALIC_TEXT = "How many **hours per week** do you work on _average_?".freeze
  UNDERLINE_TEXT = "How many **hours per week** do you work on ++average++?".freeze

  def up
    return unless table_exists?(:questions)

    execute <<~SQL
      UPDATE questions
      SET question_text = #{connection.quote(UNDERLINE_TEXT)},
          configuration = COALESCE(configuration, '{}'::jsonb) || '{"prompt_format":"rich_text"}'::jsonb,
          updated_at = CURRENT_TIMESTAMP
      WHERE question_text = #{connection.quote(ITALIC_TEXT)};
    SQL
  end

  def down
    execute <<~SQL
      UPDATE questions
      SET question_text = #{connection.quote(ITALIC_TEXT)},
          updated_at = CURRENT_TIMESTAMP
      WHERE question_text = #{connection.quote(UNDERLINE_TEXT)};
    SQL
  end
end
