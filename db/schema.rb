# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_05_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admins", primary_key: "admin_id", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "advisors", primary_key: "advisor_id", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["survey_id"], name: "index_categories_on_survey_id"
  end

  create_table "feedback", primary_key: "feedback_id", force: :cascade do |t|
    t.bigint "advisor_id", null: false
    t.bigint "category_id", null: false
    t.bigint "surveyresponse_id", null: false
    t.integer "score"
    t.text "comments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advisor_id", "category_id", "surveyresponse_id"], name: "index_feedback_on_advisor_category_response", unique: true
    t.index ["advisor_id"], name: "index_feedback_on_advisor_id"
    t.index ["category_id"], name: "index_feedback_on_category_id"
    t.index ["surveyresponse_id"], name: "index_feedback_on_surveyresponse_id"
  end

  create_table "question_responses", primary_key: "questionresponse_id", force: :cascade do |t|
    t.bigint "surveyresponse_id", null: false
    t.bigint "question_id", null: false
    t.text "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_question_responses_on_question_id"
    t.index ["surveyresponse_id", "question_id"], name: "index_question_responses_on_survey_and_question", unique: true
    t.index ["surveyresponse_id"], name: "index_question_responses_on_surveyresponse_id"
  end

  create_table "questions", primary_key: "question_id", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "question", null: false
    t.integer "question_order", null: false
    t.string "question_type", null: false
    t.text "answer_options"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "depends_on_question_id"
    t.string "depends_on_value"
    t.boolean "required", default: false, null: false
    t.index ["category_id", "question_order"], name: "index_questions_on_category_id_and_question_order", unique: true
    t.index ["category_id"], name: "index_questions_on_category_id"
    t.index ["depends_on_question_id"], name: "index_questions_on_depends_on_question_id"
  end

  create_table "students", primary_key: "student_id", force: :cascade do |t|
    t.string "uin"
    t.bigint "advisor_id"
    t.string "track"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advisor_id"], name: "index_students_on_advisor_id"
    t.index ["uin"], name: "index_students_on_uin", unique: true, where: "(uin IS NOT NULL)"
  end

  create_table "survey_responses", primary_key: "surveyresponse_id", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "advisor_id"
    t.bigint "survey_id", null: false
    t.date "completion_date"
    t.date "approval_date"
    t.string "status", default: "Not Started", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advisor_id"], name: "index_survey_responses_on_advisor_id"
    t.index ["status"], name: "index_survey_responses_on_status"
    t.index ["student_id"], name: "index_survey_responses_on_student_id"
    t.index ["survey_id"], name: "index_survey_responses_on_survey_id"
  end

  create_table "surveys", force: :cascade do |t|
    t.string "title", null: false
    t.string "semester", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", primary_key: "user_id", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.string "uid"
    t.string "avatar_url"
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "admins", "users", column: "admin_id", primary_key: "user_id", on_delete: :cascade
  add_foreign_key "advisors", "users", column: "advisor_id", primary_key: "user_id", on_delete: :cascade
  add_foreign_key "categories", "surveys"
  add_foreign_key "feedback", "advisors", primary_key: "advisor_id", on_delete: :cascade
  add_foreign_key "feedback", "categories", on_delete: :cascade
  add_foreign_key "feedback", "survey_responses", column: "surveyresponse_id", primary_key: "surveyresponse_id", on_delete: :cascade
  add_foreign_key "question_responses", "questions", primary_key: "question_id", on_delete: :cascade
  add_foreign_key "question_responses", "survey_responses", column: "surveyresponse_id", primary_key: "surveyresponse_id", on_delete: :cascade
  add_foreign_key "questions", "categories"
  add_foreign_key "questions", "questions", column: "depends_on_question_id", primary_key: "question_id", on_delete: :nullify
  add_foreign_key "students", "advisors", primary_key: "advisor_id", on_delete: :nullify
  add_foreign_key "students", "users", column: "student_id", primary_key: "user_id", on_delete: :cascade
  add_foreign_key "survey_responses", "advisors", primary_key: "advisor_id", on_delete: :nullify
  add_foreign_key "survey_responses", "students", primary_key: "student_id", on_delete: :cascade
  add_foreign_key "survey_responses", "surveys"
end
