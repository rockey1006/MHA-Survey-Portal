class CreateSurveys < ActiveRecord::Migration[8.0]
  def change
    create_table :surveys do |t|
      t.integer :survey_id
      t.date :assigned_date
      t.date :completion_date
      t.date :approval_date

      t.timestamps
    end
  end
end
