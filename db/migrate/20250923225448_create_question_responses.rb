class CreateQuestionResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :question_responses do |t|
      t.integer :questionresponse_id
      t.integer :competencyresponse_id
      t.integer :question_id
      t.string :answer

      t.timestamps
    end
  end
end
