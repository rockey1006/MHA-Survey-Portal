class CreateStudents < ActiveRecord::Migration[8.0]
  def change
    create_table :students do |t|
      t.integer :student_id
      t.string :name
      t.string :email
      t.string :NetID
      t.integer :track
      t.integer :adivsor_id

      t.timestamps
    end
  end
end
