class ConvertHoursPerWeekQuestionToInteger < ActiveRecord::Migration[8.0]
  PLAIN_TEXT    = "How many hours per week do you work on average?"
  RICH_TEXT     = "How many <strong>hours per week</strong> do you work on <u>average</u>?"
  CONFIGURATION = '{"prompt_format":"rich_text","integer_min":"1"}'

  def up
    # Matches both the legacy plain-text version (production) and the already-rich-text version.
    # Updates question_text to the rich-text form, switches type to integer,
    # and applies rich_text prompt_format + integer_min to configuration.
    execute <<~SQL
      UPDATE questions
      SET question_text  = #{connection.quote(RICH_TEXT)},
          question_type  = 'integer',
          configuration  = configuration || '#{CONFIGURATION}'::jsonb
      WHERE question_text IN (
        #{connection.quote(PLAIN_TEXT)},
        #{connection.quote(RICH_TEXT)}
      );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cannot safely restore original question_text or question_type after this migration"
  end
end
