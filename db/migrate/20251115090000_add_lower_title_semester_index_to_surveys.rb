class AddLowerTitleSemesterIndexToSurveys < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS index_surveys_on_lower_title_and_semester
      ON surveys (LOWER(title), LOWER(semester));
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_surveys_on_lower_title_and_semester;
    SQL
  end
end
