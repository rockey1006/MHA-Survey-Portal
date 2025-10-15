class AlignSchemaWithTarget < ActiveRecord::Migration[8.0]
  def up

    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :uid
      t.string :avatar_url
      t.string :role, null: false
      t.timestamps

      t.index :email, unique: true
      t.index :uid, unique: true
      t.index :role
    end

    create_table :admins, primary_key: :admin_id do |t|
      t.timestamps
    end
    add_foreign_key :admins, :users, column: :admin_id, on_delete: :cascade

    create_table :advisors, primary_key: :advisor_id do |t|
      t.timestamps
    end
    add_foreign_key :advisors, :users, column: :advisor_id, on_delete: :cascade

    create_table :students, primary_key: :student_id do |t|
      t.string :uin
      t.bigint :advisor_id
      t.string :track
      t.timestamps

      t.index :advisor_id
      t.index :uin, unique: true, where: "uin IS NOT NULL"
    end
    add_foreign_key :students, :users, column: :student_id, on_delete: :cascade
  add_foreign_key :students, :advisors, column: :advisor_id, primary_key: :advisor_id, on_delete: :cascade

    create_table :notifications do |t|
      t.string :title, null: false
      t.text :message
      t.string :notifiable_type, null: false
      t.bigint :notifiable_id, null: false
      t.datetime :read_at
      t.timestamps

      t.index [ :notifiable_type, :notifiable_id ], name: "index_notifications_on_notifiable"
    end

    create_table :surveys do |t|
      t.string :title, null: false
      t.string :semester, null: false
      t.timestamps
    end

    create_table :categories do |t|
      t.string :name, null: false
      t.string :description
      t.timestamps
    end

    create_table :questions do |t|
      t.string :question, null: false
      t.integer :question_order, null: false
      t.boolean :required, null: false, default: false
      t.string :question_type, null: false
      t.text :answer_options
      t.timestamps
    end
    add_index :questions, :question_order

    create_table :survey_questions do |t|
      t.references :survey, null: false, foreign_key: { on_delete: :cascade }
      t.references :question, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps

      t.index [ :survey_id, :question_id ], unique: true
    end

    create_table :category_questions do |t|
      t.references :category, null: false, foreign_key: { on_delete: :cascade }
      t.references :question, null: false, foreign_key: { on_delete: :cascade }
      t.string :display_label
      t.string :description
      t.timestamps

      t.index [ :category_id, :question_id ], unique: true
    end

    create_table :student_questions do |t|
      t.references :student, null: false, foreign_key: { to_table: :students, primary_key: :student_id, on_delete: :cascade }
      t.references :advisor, null: true, foreign_key: { to_table: :advisors, primary_key: :advisor_id, on_delete: :cascade }
      t.references :question, null: false, foreign_key: { on_delete: :cascade }
      t.string :response_value
      t.timestamps

      t.index [ :student_id, :question_id ], unique: true
    end

    create_table :feedback do |t|
      t.references :student, null: false, foreign_key: { to_table: :students, primary_key: :student_id, on_delete: :cascade }
      t.references :advisor, null: false, foreign_key: { to_table: :advisors, primary_key: :advisor_id, on_delete: :cascade }
      t.references :category, null: false, foreign_key: { on_delete: :cascade }
      t.references :survey, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.float :average_score
      t.string :comments
      t.timestamps
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "AlignSchemaWithTarget cannot be rolled back"
  end
end