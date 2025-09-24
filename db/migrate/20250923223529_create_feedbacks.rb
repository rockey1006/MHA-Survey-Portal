class CreateFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :feedbacks do |t|
      t.integer :feedback_id
      t.integer :advisor_id
      t.integer :competency_id
      t.integer :rating
      t.string :comments

      t.timestamps
    end
  end
end
