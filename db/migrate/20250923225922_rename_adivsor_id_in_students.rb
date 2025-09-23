class RenameAdivsorIdInStudents < ActiveRecord::Migration[8.0]
  def change
    rename_column :students, :adivsor_id, :advisor_id
  end
end
