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

ActiveRecord::Schema[8.0].define(version: 2025_09_24_154224) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.integer "admin_id"
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "advisors", force: :cascade do |t|
    t.integer "advisor_id"
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "competencies", force: :cascade do |t|
    t.integer "competency_id"
    t.integer "survey_id"
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "competency_responses", force: :cascade do |t|
    t.integer "competencyresponse_id"
    t.integer "surveyresponse_id"
    t.integer "competency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "evidence_uploads", force: :cascade do |t|
    t.integer "evidenceupload_id"
    t.integer "questionresponse_id"
    t.integer "competencyresponse_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "link"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.integer "feedback_id"
    t.integer "advisor_id"
    t.integer "competency_id"
    t.integer "rating"
    t.string "comments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "question_responses", force: :cascade do |t|
    t.integer "questionresponse_id"
    t.integer "competencyresponse_id"
    t.integer "question_id"
    t.string "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "questions", force: :cascade do |t|
    t.integer "question_id"
    t.integer "competency_id"
    t.integer "question_order"
    t.string "question_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "students", force: :cascade do |t|
    t.integer "student_id"
    t.string "name"
    t.string "email"
    t.string "NetID"
    t.integer "track"
    t.integer "advisor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "survey_responses", force: :cascade do |t|
    t.integer "surveyresponse_id"
    t.integer "student_id"
    t.integer "advisor_id"
    t.integer "survey_id"
    t.string "semester"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "surveys", force: :cascade do |t|
    t.integer "survey_id"
    t.date "assigned_date"
    t.date "completion_date"
    t.date "approval_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
