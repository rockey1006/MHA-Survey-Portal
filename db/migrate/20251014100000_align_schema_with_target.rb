class AlignSchemaWithTarget < ActiveRecord::Migration[8.0]
  def up
    create_enum :student_classifications, %w[G1 G2 G3]
    create_enum :student_tracks, %w[Residential Executive]
    create_enum :question_types, %w[multiple_choice scale short_answer evidence]

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
      t.enum :track, enum_type: :student_tracks, null: false, default: "Residential"
      t.enum :classification, enum_type: :student_classifications, null: false, default: "G1"
      t.timestamps

      t.index :advisor_id
      t.index :uin, unique: true, where: "uin IS NOT NULL"
    end
    add_foreign_key :students, :users, column: :student_id, on_delete: :cascade
    add_foreign_key :students, :advisors, column: :advisor_id, primary_key: :advisor_id, on_delete: :nullify

    create_table :notifications do |t|
      t.string :title, null: false
      t.text :message
      t.string :notifiable_type, null: false
      t.bigint :notifiable_id, null: false
      t.datetime :read_at
      t.timestamps

      t.index %i[notifiable_type notifiable_id], name: "index_notifications_on_notifiable"
    end

    create_table :surveys do |t|
      t.string :title, null: false
      t.string :semester, null: false
      t.text :description
      t.boolean :is_active, null: false, default: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :surveys, :semester
    add_index :surveys, :is_active

    create_table :categories do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.string :name, null: false
      t.string :description
      t.timestamps
    end

    create_table :questions do |t|
      t.references :category, null: false, foreign_key: { to_table: :categories, on_delete: :cascade }
      t.string :question_text, null: false
      t.integer :question_order, null: false
      t.boolean :is_required, null: false, default: false
      t.enum :question_type, enum_type: :question_types, null: false
      t.text :answer_options
      t.boolean :has_evidence_field, null: false, default: false
      t.timestamps
    end
    add_index :questions, %i[category_id question_order]
    add_index :questions, :question_type

    create_table :survey_assignments do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.string :track, null: false
      t.timestamps
    end
    add_index :survey_assignments, %i[survey_id track], unique: true

    create_table :survey_questions do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.references :question, null: false, foreign_key: { to_table: :questions, on_delete: :cascade }
      t.timestamps
    end
    add_index :survey_questions, %i[survey_id question_id], unique: true

    create_table :category_questions do |t|
      t.references :category, null: false, foreign_key: { to_table: :categories, on_delete: :cascade }
      t.references :question, null: false, foreign_key: { to_table: :questions, on_delete: :cascade }
      t.string :display_label
      t.string :description
      t.timestamps
    end
    add_index :category_questions, %i[category_id question_id], unique: true

    create_table :student_questions do |t|
      t.references :student, null: false, foreign_key: { to_table: :students, primary_key: :student_id, on_delete: :cascade }
      t.references :advisor, foreign_key: { to_table: :advisors, primary_key: :advisor_id, on_delete: :nullify }
      t.references :question, null: false, foreign_key: { to_table: :questions, on_delete: :cascade }
      t.string :response_value
      t.timestamps
    end
    add_index :student_questions, %i[student_id question_id], unique: true

    create_table :survey_category_tags do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.references :category, null: false, foreign_key: { to_table: :categories, on_delete: :cascade }
      t.timestamps
    end
    add_index :survey_category_tags, %i[survey_id category_id], unique: true

    create_table :survey_audit_logs do |t|
      t.references :survey, foreign_key: { to_table: :surveys, on_delete: :nullify }
      t.references :admin, null: false, foreign_key: { to_table: :admins, primary_key: :admin_id, on_delete: :cascade }
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :survey_audit_logs, :created_at
    add_index :survey_audit_logs, :action

    create_table :survey_change_logs do |t|
      t.references :survey, foreign_key: { to_table: :surveys, on_delete: :nullify }
      t.references :admin, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :action, null: false
      t.text :description
      t.timestamps
    end
    add_index :survey_change_logs, :created_at

    create_table :feedback do |t|
      t.references :student, null: false, foreign_key: { to_table: :students, primary_key: :student_id, on_delete: :cascade }
      t.references :advisor, null: false, foreign_key: { to_table: :advisors, primary_key: :advisor_id, on_delete: :cascade }
      t.references :category, null: false, foreign_key: { to_table: :categories, on_delete: :cascade }
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.float :average_score
      t.string :comments
      t.timestamps
    end
    add_index :feedback, :survey_id, unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "AlignSchemaWithTarget cannot be rolled back"
  end
end