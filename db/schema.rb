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

ActiveRecord::Schema[8.0].define(version: 2025_10_14_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_activity_logs", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.string "action", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.jsonb "metadata", default: {}, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_admin_activity_logs_on_admin_id"
    t.index ["subject_type", "subject_id"], name: "index_admin_activity_logs_on_subject"
  end

  create_table "admins", primary_key: "admin_id", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "advisors", primary_key: "advisor_id", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "survey_id"
    t.bigint "survey_section_id"
    t.index ["survey_id"], name: "index_categories_on_survey_id"
    t.index ["survey_section_id"], name: "index_categories_on_survey_section_id"
  end

  create_table "feedback", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "advisor_id", null: false
    t.bigint "category_id", null: false
    t.bigint "survey_id", null: false
    t.float "average_score"
    t.string "comments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "question_id"
    t.index ["advisor_id"], name: "index_feedback_on_advisor_id"
    t.index ["category_id"], name: "index_feedback_on_category_id"
    t.index ["question_id"], name: "index_feedback_on_question_id"
    t.index ["student_id"], name: "index_feedback_on_student_id"
    t.index ["survey_id"], name: "index_feedback_on_survey_id"
  end

  create_table "majors", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_majors_on_name", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.string "title", null: false
    t.text "message"
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_and_read_at"
    t.index ["user_id", "title", "notifiable_type", "notifiable_id"], name: "index_notifications_unique_per_user", unique: true
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "program_semesters", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "current", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["current"], name: "index_program_semesters_on_current", where: "(current = true)"
    t.index ["name"], name: "index_program_semesters_on_name", unique: true
  end

  create_table "questions", force: :cascade do |t|
    t.string "question_text", null: false
    t.text "description"
    t.text "tooltip_text"
    t.integer "question_order", null: false
    t.boolean "is_required", default: false, null: false
    t.string "question_type", null: false
    t.text "answer_options"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.boolean "has_evidence_field", default: false, null: false
    t.boolean "has_feedback", default: false, null: false
    t.jsonb "configuration", default: {}, null: false
    t.integer "program_target_level"
    t.bigint "parent_question_id"
    t.integer "sub_question_order", default: 0, null: false
    t.index ["category_id", "question_order"], name: "index_questions_on_category_id_and_question_order"
    t.index ["category_id"], name: "index_questions_on_category_id"
    t.index ["parent_question_id", "sub_question_order"], name: "index_questions_on_parent_and_sub_order"
    t.index ["parent_question_id"], name: "index_questions_on_parent_question_id"
    t.index ["question_order"], name: "index_questions_on_question_order"
  end

  create_table "student_questions", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "advisor_id"
    t.bigint "question_id", null: false
    t.string "response_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advisor_id"], name: "index_student_questions_on_advisor_id"
    t.index ["question_id"], name: "index_student_questions_on_question_id"
    t.index ["student_id", "question_id"], name: "index_student_questions_on_student_id_and_question_id", unique: true
    t.index ["student_id"], name: "index_student_questions_on_student_id"
  end

  create_table "students", primary_key: "student_id", force: :cascade do |t|
    t.string "uin"
    t.bigint "advisor_id"
    t.string "track"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "major"
    t.index ["advisor_id"], name: "index_students_on_advisor_id"
    t.index ["uin"], name: "index_students_on_uin", unique: true, where: "(uin IS NOT NULL)"
  end

  create_table "survey_assignments", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.bigint "student_id", null: false
    t.bigint "advisor_id"
    t.datetime "assigned_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "due_date"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_date", "completed_at"], name: "index_survey_assignments_due_date"
    t.index ["survey_id", "student_id"], name: "index_survey_assignments_on_survey_and_student", unique: true
    t.index ["survey_id"], name: "index_survey_assignments_on_survey_id"
  end

  create_table "survey_change_logs", force: :cascade do |t|
    t.bigint "survey_id"
    t.bigint "admin_id", null: false
    t.string "action", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_survey_change_logs_on_admin_id"
    t.index ["survey_id"], name: "index_survey_change_logs_on_survey_id"
  end

  create_table "survey_legends", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.string "title"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["survey_id"], name: "index_survey_legends_on_survey_id", unique: true
  end

  create_table "survey_sections", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["survey_id", "position"], name: "index_survey_sections_on_survey_id_and_position"
    t.index ["survey_id"], name: "index_survey_sections_on_survey_id"
  end

  create_table "survey_track_assignments", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "track", null: false
    t.index ["survey_id", "track"], name: "index_survey_track_assignments_on_survey_id_and_track", unique: true
    t.index ["survey_id"], name: "index_survey_track_assignments_on_survey_id"
  end

  create_table "surveys", force: :cascade do |t|
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "track"
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.bigint "created_by_id"
    t.bigint "program_semester_id", null: false
    t.index "lower((title)::text), program_semester_id", name: "index_surveys_on_lower_title_and_program_semester", unique: true
    t.index ["created_by_id"], name: "index_surveys_on_created_by_id"
    t.index ["is_active"], name: "index_surveys_on_is_active"
    t.index ["program_semester_id"], name: "index_surveys_on_program_semester_id"
    t.index ["track"], name: "index_surveys_on_track"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.string "uid"
    t.string "avatar_url"
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "failed_mfa_attempts", default: 0, null: false
    t.datetime "mfa_locked_at"
    t.string "language"
    t.boolean "notifications_enabled", default: true, null: false
    t.integer "text_scale_percent", default: 100, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "admin_activity_logs", "users", column: "admin_id", on_delete: :cascade
  add_foreign_key "admins", "users", column: "admin_id", on_delete: :cascade
  add_foreign_key "advisors", "users", column: "advisor_id", on_delete: :cascade
  add_foreign_key "categories", "survey_sections", on_delete: :nullify
  add_foreign_key "categories", "surveys"
  add_foreign_key "feedback", "advisors", primary_key: "advisor_id", on_delete: :cascade
  add_foreign_key "feedback", "categories", on_delete: :cascade
  add_foreign_key "feedback", "questions"
  add_foreign_key "feedback", "students", primary_key: "student_id", on_delete: :cascade
  add_foreign_key "feedback", "surveys", on_delete: :cascade
  add_foreign_key "notifications", "users", on_delete: :cascade
  add_foreign_key "questions", "categories"
  add_foreign_key "questions", "questions", column: "parent_question_id"
  add_foreign_key "student_questions", "advisors", primary_key: "advisor_id", on_delete: :cascade
  add_foreign_key "student_questions", "questions", on_delete: :cascade
  add_foreign_key "student_questions", "students", primary_key: "student_id", on_delete: :cascade
  add_foreign_key "students", "advisors", primary_key: "advisor_id", on_delete: :cascade
  add_foreign_key "students", "users", column: "student_id", on_delete: :cascade
  add_foreign_key "survey_assignments", "advisors", primary_key: "advisor_id", on_delete: :nullify
  add_foreign_key "survey_assignments", "students", primary_key: "student_id", on_delete: :cascade
  add_foreign_key "survey_assignments", "surveys", on_delete: :cascade
  add_foreign_key "survey_change_logs", "surveys", on_delete: :nullify
  add_foreign_key "survey_change_logs", "users", column: "admin_id"
  add_foreign_key "survey_legends", "surveys"
  add_foreign_key "survey_sections", "surveys", on_delete: :cascade
  add_foreign_key "survey_track_assignments", "surveys", on_delete: :cascade
  add_foreign_key "surveys", "program_semesters"
  add_foreign_key "surveys", "users", column: "created_by_id"
end
