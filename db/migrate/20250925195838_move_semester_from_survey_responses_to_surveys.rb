class MoveSemesterFromSurveyResponsesToSurveys < ActiveRecord::Migration[8.0]
  def change
    remove_column :survey_responses, :semester, :string
    add_column :surveys, :semester, :string
  end
end
