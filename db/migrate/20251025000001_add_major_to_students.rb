class AddMajorToStudents < ActiveRecord::Migration[8.0]
  def change
    add_column :students, :major, :string
  end
end
