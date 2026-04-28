class CreateGradeImportTables < ActiveRecord::Migration[8.0]
  def change
    create_table :grade_import_batches do |t|
      t.bigint :uploaded_by_id, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_files, null: false, default: 0
      t.integer :processed_files, null: false, default: 0
      t.integer :failed_files, null: false, default: 0
      t.integer :evidence_count, null: false, default: 0
      t.integer :rating_count, null: false, default: 0
      t.integer :pending_count, null: false, default: 0
      t.jsonb :summary, null: false, default: {}
      t.timestamps
    end

    add_index :grade_import_batches, :uploaded_by_id
    add_index :grade_import_batches, :status
    add_foreign_key :grade_import_batches, :users, column: :uploaded_by_id, on_delete: :cascade

    create_table :grade_import_files do |t|
      t.references :grade_import_batch, null: false, foreign_key: { on_delete: :cascade }
      t.string :file_name, null: false
      t.string :file_checksum, null: false
      t.string :content_type
      t.string :status, null: false, default: "pending"
      t.integer :total_rows, null: false, default: 0
      t.integer :imported_rows, null: false, default: 0
      t.integer :pending_rows, null: false, default: 0
      t.integer :error_rows, null: false, default: 0
      t.jsonb :parse_errors, null: false, default: []
      t.jsonb :parsed_content, null: false, default: {}
      t.timestamps
    end

    add_index :grade_import_files, :status
    add_index :grade_import_files, :file_checksum

    create_table :grade_competency_evidences do |t|
      t.references :grade_import_batch, null: false, foreign_key: { on_delete: :cascade }
      t.references :grade_import_file, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :student_id, null: false
      t.string :competency_title, null: false
      t.string :course_code
      t.string :assignment_name
      t.decimal :raw_grade, precision: 8, scale: 2, null: false
      t.integer :mapped_level, null: false
      t.integer :row_number
      t.string :source_key, null: false
      t.string :import_fingerprint, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :grade_competency_evidences, [ :grade_import_batch_id, :student_id ], name: "index_grade_evidence_on_batch_student"
    add_index :grade_competency_evidences, [ :grade_import_batch_id, :competency_title ], name: "index_grade_evidence_on_batch_competency"
    add_index :grade_competency_evidences, [ :grade_import_batch_id, :source_key ], unique: true, name: "index_grade_evidence_on_batch_source_key"
    add_index :grade_competency_evidences, :import_fingerprint, unique: true
    add_foreign_key :grade_competency_evidences, :students, column: :student_id, primary_key: :student_id, on_delete: :cascade

    create_table :grade_competency_ratings do |t|
      t.references :grade_import_batch, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :student_id, null: false
      t.string :competency_title, null: false
      t.decimal :aggregated_level, precision: 4, scale: 2, null: false
      t.string :aggregation_rule, null: false, default: "max"
      t.integer :evidence_count, null: false, default: 0
      t.timestamps
    end

    add_index :grade_competency_ratings, [ :grade_import_batch_id, :student_id, :competency_title ], unique: true, name: "index_grade_ratings_on_batch_student_competency"
    add_foreign_key :grade_competency_ratings, :students, column: :student_id, primary_key: :student_id, on_delete: :cascade

    create_table :grade_import_pending_rows do |t|
      t.references :grade_import_batch, null: false, foreign_key: { on_delete: :cascade }
      t.references :grade_import_file, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :matched_student_id
      t.string :status, null: false, default: "pending_student_match"
      t.string :student_identifier
      t.string :student_identifier_type
      t.string :student_uin
      t.string :student_email
      t.string :student_name
      t.string :competency_title, null: false
      t.string :course_code
      t.string :assignment_name
      t.decimal :raw_grade, precision: 8, scale: 2, null: false
      t.integer :mapped_level, null: false
      t.integer :row_number
      t.string :source_key, null: false
      t.string :import_fingerprint, null: false
      t.datetime :reconciled_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :grade_import_pending_rows, :status
    add_index :grade_import_pending_rows, [ :grade_import_batch_id, :status ], name: "index_grade_pending_rows_on_batch_status"
    add_index :grade_import_pending_rows, [ :grade_import_batch_id, :student_uin ], name: "index_grade_pending_rows_on_batch_uin"
    add_index :grade_import_pending_rows, [ :grade_import_batch_id, :student_email ], name: "index_grade_pending_rows_on_batch_email"
    add_index :grade_import_pending_rows, [ :grade_import_batch_id, :source_key ], unique: true, name: "index_grade_pending_rows_on_batch_source_key"
    add_index :grade_import_pending_rows, :import_fingerprint, unique: true
    add_foreign_key :grade_import_pending_rows, :students, column: :matched_student_id, primary_key: :student_id, on_delete: :nullify
  end
end
