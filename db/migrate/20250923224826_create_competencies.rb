class CreateCompetencies < ActiveRecord::Migration[8.0]
  def change
    create_table :competencies do |t|
      t.integer :competency_id
      t.integer :survey_id
      t.string :name
      t.string :description

      t.timestamps
    end
  end
end
