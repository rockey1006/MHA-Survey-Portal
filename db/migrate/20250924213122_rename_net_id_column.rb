class RenameNetIdColumn < ActiveRecord::Migration[8.0]
  def change
    rename_column :students, :NetID, :net_id
  end
end
