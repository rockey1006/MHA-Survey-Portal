class CreateAdvisors < ActiveRecord::Migration[8.0]
  def change
    create_table :advisors do |t|
      t.integer :advisor_id
      t.string :name
      t.string :email

      t.timestamps
    end
  end
end
