# frozen_string_literal: true

class UpdateEvidenceQuestionTextToGoogleSites < ActiveRecord::Migration[7.1]
  OLD_TEXT = "Please provide a link to your (Google Drive) MHA Portfolio as evidence for this survey."
  NEW_TEXT = "Please provide a link to your MHA Portfolio (Google Sites) as evidence for this survey."

  def up
    return unless table_exists?(:questions)
    return unless column_exists?(:questions, :question_text)
    return unless column_exists?(:questions, :question_type)

    execute <<~SQL.squish
      UPDATE questions
      SET question_text = #{connection.quote(NEW_TEXT)}
      WHERE question_text = #{connection.quote(OLD_TEXT)}
        AND question_type = 'evidence'
    SQL
  end

  def down
    return unless table_exists?(:questions)
    return unless column_exists?(:questions, :question_text)
    return unless column_exists?(:questions, :question_type)

    execute <<~SQL.squish
      UPDATE questions
      SET question_text = #{connection.quote(OLD_TEXT)}
      WHERE question_text = #{connection.quote(NEW_TEXT)}
        AND question_type = 'evidence'
    SQL
  end
end
