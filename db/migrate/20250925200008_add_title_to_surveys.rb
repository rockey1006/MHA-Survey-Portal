class AddTitleToSurveys < ActiveRecord::Migration[8.0]
  def change
    add_column :surveys, :title, :string
  end
end
