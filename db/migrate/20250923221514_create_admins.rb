class CreateAdmins < ActiveRecord::Migration[8.0]
  def change
    create_table :admins do |t|
      t.integer :admin_id
      t.string :name
      t.string :email

      t.timestamps
    end
  end
end
