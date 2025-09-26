class AddSemesterToSurveyResponses < ActiveRecord::Migration[8.0]
  def change
      # Sometimes the schema was already applied (e.g. via schema:load) so be defensive.
      # return if connection.columns(:survey_responses).map(&:name).include?("semester")

      # Use a Postgres-safe ALTER TABLE ... ADD COLUMN IF NOT EXISTS so this migration
      # can be re-run without failing when the column already exists (e.g. after schema:load).
      execute <<~SQL
        ALTER TABLE survey_responses
        ADD COLUMN IF NOT EXISTS semester varchar;
      SQL
  end
end
