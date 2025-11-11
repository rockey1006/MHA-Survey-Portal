class AddSettingsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :language, :string
    add_column :users, :notifications_enabled, :boolean, default: true, null: false
  end
end
