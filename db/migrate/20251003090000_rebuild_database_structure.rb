class RebuildDatabaseStructure < ActiveRecord::Migration[8.0]
  def up
    # Drop legacy tables that will be replaced by the new schema
    %i[
      competency_responses
      competencies
      feedbacks
      question_responses
      questions
      survey_responses
      surveys
      students
      advisors
      admins
    ].each do |table_name|
      drop_table table_name, force: :cascade, if_exists: true
    end

    # Core users table
    create_table :users, primary_key: :user_id do |t|
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

    # Role-specific tables backed by users
    create_table :admins, primary_key: :admin_id do |t|
      t.timestamps
    end
    add_foreign_key :admins, :users, column: :admin_id, primary_key: :user_id, on_delete: :cascade

    create_table :advisors, primary_key: :advisor_id do |t|
      t.timestamps
    end
    add_foreign_key :advisors, :users, column: :advisor_id, primary_key: :user_id, on_delete: :cascade

    create_table :students, primary_key: :student_id do |t|
      t.string :uin
      t.bigint :advisor_id
      t.string :track
      t.timestamps

      t.index :advisor_id
      t.index :uin, unique: true, where: "uin IS NOT NULL"
    end
    add_foreign_key :students, :users, column: :student_id, primary_key: :user_id, on_delete: :cascade
    add_foreign_key :students, :advisors, column: :advisor_id, primary_key: :advisor_id, on_delete: :nullify

    # Surveys and survey content
    create_table :surveys do |t|
      t.string :title, null: false
      t.string :semester, null: false
      t.timestamps
    end

    create_table :categories do |t|
      t.references :survey, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :questions, primary_key: :question_id do |t|
      t.references :category, null: false, foreign_key: true
      t.string :question, null: false
      t.integer :question_order, null: false
      t.string :question_type, null: false
      t.text :answer_options
      t.timestamps

      t.index [ :category_id, :question_order ], unique: true, name: "index_questions_on_category_id_and_question_order"
    end

    create_table :survey_responses, primary_key: :surveyresponse_id do |t|
      t.bigint :student_id, null: false
      t.bigint :advisor_id
      t.bigint :survey_id, null: false
      t.date :completion_date
      t.date :approval_date
      t.string :status, null: false, default: "Not Started"
      t.timestamps

      t.index :student_id
      t.index :advisor_id
      t.index :survey_id
      t.index :status
    end
    add_foreign_key :survey_responses, :students, column: :student_id, primary_key: :student_id, on_delete: :cascade
    add_foreign_key :survey_responses, :advisors, column: :advisor_id, primary_key: :advisor_id, on_delete: :nullify
    add_foreign_key :survey_responses, :surveys, column: :survey_id

    create_table :question_responses, primary_key: :questionresponse_id do |t|
      t.bigint :surveyresponse_id, null: false
      t.bigint :question_id, null: false
      t.text :answer
      t.timestamps

      t.index :surveyresponse_id
      t.index :question_id
      t.index [ :surveyresponse_id, :question_id ], unique: true, name: "index_question_responses_on_survey_and_question"
    end
    add_foreign_key :question_responses, :survey_responses, column: :surveyresponse_id, primary_key: :surveyresponse_id, on_delete: :cascade
    add_foreign_key :question_responses, :questions, column: :question_id, primary_key: :question_id, on_delete: :cascade

    create_table :feedback, primary_key: :feedback_id do |t|
      t.bigint :advisor_id, null: false
      t.bigint :category_id, null: false
      t.bigint :surveyresponse_id, null: false
      t.integer :score
      t.text :comments
      t.timestamps

      t.index :advisor_id
      t.index :category_id
      t.index :surveyresponse_id
      t.index [ :advisor_id, :category_id, :surveyresponse_id ], unique: true, name: "index_feedback_on_advisor_category_response"
    end
    add_foreign_key :feedback, :advisors, column: :advisor_id, primary_key: :advisor_id, on_delete: :cascade
    add_foreign_key :feedback, :categories, column: :category_id, on_delete: :cascade
    add_foreign_key :feedback, :survey_responses, column: :surveyresponse_id, primary_key: :surveyresponse_id, on_delete: :cascade
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "RebuildDatabaseStructure cannot be rolled back"
  end
end
