class CreateCompetencyResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :competency_responses do |t|
      t.integer :competencyresponse_id
      t.integer :surveyresponse_id
      t.integer :competency_id

      t.timestamps
    end
  end
end
