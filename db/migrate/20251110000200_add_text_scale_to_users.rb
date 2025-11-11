class AddTextScaleToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :text_scale_percent, :integer, default: 100, null: false
  end
end
