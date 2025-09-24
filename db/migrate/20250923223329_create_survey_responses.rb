class CreateSurveyResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :survey_responses do |t|
      t.integer :surveyresponse_id
      t.integer :student_id
      t.integer :advisor_id
      t.integer :survey_id
      t.string :semester
      t.integer :status

      t.timestamps
    end
  end
end
