class AlignSchemaWithTarget < ActiveRecord::Migration[8.0]
  SECTION_TITLE = "MHA Competency Self-Assessment".freeze
  SECTION_DESCRIPTION = "Please review each of the 17 competencies that make up the MHA Competency Model and determine your level of proficiency (achievement) at this point in your program. Click on the information button for a description of the 1-5 proficiency scale.".freeze
  CATEGORY_NAMES = [
    "Health Care Environment and Community",
    "Leadership Skills",
    "Management Skills",
    "Analytic and Technical Skills"
  ].freeze

  class MigrationSurveySection < ActiveRecord::Base
    self.table_name = "survey_sections"
    has_many :categories, class_name: "AlignSchemaWithTarget::MigrationCategory"
  end

  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
    belongs_to :survey_section, class_name: "AlignSchemaWithTarget::MigrationSurveySection", optional: true
    has_many :questions, class_name: "AlignSchemaWithTarget::MigrationQuestion"
  end

  class MigrationQuestion < ActiveRecord::Base
    self.table_name = "questions"
    belongs_to :category, class_name: "AlignSchemaWithTarget::MigrationCategory", optional: true
  end

  def up
    create_enum :student_classifications, %w[G1 G2 G3]
    create_enum :student_tracks, %w[Residential Executive]
    create_enum :question_types, %w[multiple_choice dropdown scale short_answer evidence]

  # Entity table: application user accounts (students, advisors, admins).
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :uid
      t.string :avatar_url
      t.string :role, null: false
      t.string :language
      t.boolean :notifications_enabled, null: false, default: true
      t.integer :text_scale_percent, null: false, default: 100
      t.timestamps

      t.index :email, unique: true
      t.index :uid, unique: true
      t.index :role
    end

  # Entity table: site-wide configuration settings.
  create_table :site_settings do |t|
      t.string :key, null: false
      t.string :value
      t.timestamps
    end
    add_index :site_settings, :key, unique: true

  # Entity table: admin role profile (1:1 with users).
  create_table :admins, primary_key: :admin_id do |t|
      t.timestamps
    end
    add_foreign_key :admins, :users, column: :admin_id, on_delete: :cascade

  # Entity table: advisor role profile (1:1 with users).
  create_table :advisors, primary_key: :advisor_id do |t|
      t.timestamps
    end
    add_foreign_key :advisors, :users, column: :advisor_id, on_delete: :cascade

  # Entity table: student role profile (1:1 with users).
  create_table :students, primary_key: :student_id do |t|
      t.string :uin
      t.bigint :advisor_id
      t.string :major
      t.enum :track, enum_type: :student_tracks, null: false, default: "Residential"
      t.enum :classification, enum_type: :student_classifications, null: false, default: "G1"
      t.timestamps

      t.index :advisor_id
      t.index :uin, unique: true, where: "uin IS NOT NULL"
    end
    add_foreign_key :students, :users, column: :student_id, on_delete: :cascade
    add_foreign_key :students, :advisors, column: :advisor_id, primary_key: :advisor_id, on_delete: :nullify

  # Entity table: majors (available options for student major/program).
  create_table :majors do |t|
      t.string :name, null: false
      t.timestamps

      t.index :name, unique: true
    end

  # Entity table: in-app notification records per user.
  create_table :notifications do |t|
      t.references :user, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :title, null: false
      t.text :message
      t.string :notifiable_type
      t.bigint :notifiable_id
      t.datetime :read_at
      t.timestamps

      t.index %i[notifiable_type notifiable_id], name: "index_notifications_on_notifiable"
      t.index %i[user_id read_at], name: "index_notifications_on_user_and_read_at"
      t.index %i[user_id title notifiable_type notifiable_id], unique: true, name: "index_notifications_unique_per_user"
    end

  # Entity table: available program semesters (used for survey assignment windows).
  create_table :program_semesters do |t|
      t.string :name, null: false
      t.boolean :current, null: false, default: false
      t.timestamps
    end
    add_index :program_semesters, :name, unique: true
    add_index :program_semesters, :current, where: "current = true"

  # Entity table: survey definitions.
  create_table :surveys do |t|
      t.string :title, null: false
      t.references :program_semester, null: false, foreign_key: { to_table: :program_semesters }
      t.text :description
      t.boolean :is_active, null: false, default: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :surveys, :is_active
    execute <<~SQL
      CREATE UNIQUE INDEX IF NOT EXISTS index_surveys_on_lower_title_and_program_semester
      ON surveys (LOWER(title), program_semester_id);
    SQL

  # Entity table: survey legend content for the student-facing sidebar.
  create_table :survey_legends do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }, index: { unique: true }
      t.string :title
      t.text :body, null: false
      t.timestamps
    end

  # Logical sections grouping related categories (used for instructions/banners).
  create_table :survey_sections do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.string :title, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.timestamps

      t.index %i[survey_id position], name: "index_survey_sections_on_survey_id_and_position"
    end

  # Entity table: survey categories grouping related questions.
  create_table :categories do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.references :survey_section, foreign_key: { to_table: :survey_sections, on_delete: :nullify }
      t.string :name, null: false
      t.string :description
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index %i[survey_id position], name: "index_categories_on_survey_id_and_position"
    end

  # Entity table: individual survey questions.
  create_table :questions do |t|
      t.references :category, null: false, foreign_key: { to_table: :categories, on_delete: :cascade }
      t.references :parent_question, foreign_key: { to_table: :questions }, null: true
      t.string :question_text, null: false
      t.text :description
      t.text :tooltip_text
      t.integer :question_order, null: false
      t.integer :sub_question_order, null: false, default: 0
      t.boolean :is_required, null: false, default: false
      t.enum :question_type, enum_type: :question_types, null: false
      t.text :answer_options
      t.integer :program_target_level
      t.boolean :has_feedback, null: false, default: false
      t.boolean :has_evidence_field, null: false, default: false
      t.timestamps
    end
    add_index :questions, %i[category_id question_order]
    add_index :questions, :question_type
    add_index :questions, %i[parent_question_id sub_question_order], name: "index_questions_on_parent_and_sub_order"

  # Join table: links surveys to named program tracks.
  create_table :survey_track_assignments do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.string :track, null: false
      t.timestamps
    end
    add_index :survey_track_assignments, %i[survey_id track], unique: true, name: "index_survey_track_assignments_on_survey_id_and_track"

  # Join table (with attributes): assigns surveys to students and advisors.
  create_table :survey_assignments do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.references :student, null: false, foreign_key: { to_table: :students, primary_key: :student_id, on_delete: :cascade }
      t.references :advisor, foreign_key: { to_table: :advisors, primary_key: :advisor_id, on_delete: :nullify }
      t.datetime :assigned_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :due_date
      t.datetime :completed_at
      t.timestamps
    end
    add_index :survey_assignments, %i[survey_id student_id], unique: true, name: "index_survey_assignments_on_survey_and_student"
    add_index :survey_assignments, %i[due_date completed_at], name: "index_survey_assignments_due_date"

  # Join table: associates surveys with their questions.
  create_table :survey_questions do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.references :question, null: false, foreign_key: { to_table: :questions, on_delete: :cascade }
      t.timestamps
    end
    add_index :survey_questions, %i[survey_id question_id], unique: true

  # Join table: maps questions into categories.
  create_table :category_questions do |t|
      t.references :category, null: false, foreign_key: { to_table: :categories, on_delete: :cascade }
      t.references :question, null: false, foreign_key: { to_table: :questions, on_delete: :cascade }
      t.string :display_label
      t.string :description
      t.timestamps
    end
    add_index :category_questions, %i[category_id question_id], unique: true

  # Join table (with responses): stores student answers per question.
  create_table :student_questions do |t|
      t.references :student, null: false, foreign_key: { to_table: :students, primary_key: :student_id, on_delete: :cascade }
      t.references :advisor, foreign_key: { to_table: :advisors, primary_key: :advisor_id, on_delete: :nullify }
      t.references :question, null: false, foreign_key: { to_table: :questions, on_delete: :cascade }
      t.string :response_value
      t.timestamps
    end
    add_index :student_questions, %i[student_id question_id], unique: true

  # Entity table: immutable snapshots of survey responses (version history).
  create_table :survey_response_versions do |t|
      t.bigint :student_id, null: false
      t.bigint :survey_id, null: false
      t.bigint :advisor_id
      t.bigint :survey_assignment_id
      t.bigint :actor_user_id
      t.string :actor_role
      t.string :event, null: false
      t.jsonb :answers, null: false, default: {}
      t.timestamps
    end

    add_index :survey_response_versions, %i[student_id survey_id created_at], name: "index_srv_versions_on_student_survey_created"
    add_index :survey_response_versions, :survey_assignment_id
    add_index :survey_response_versions, :actor_user_id

    add_foreign_key :survey_response_versions, :students, column: :student_id, primary_key: :student_id
    add_foreign_key :survey_response_versions, :surveys, column: :survey_id
    add_foreign_key :survey_response_versions, :survey_assignments, column: :survey_assignment_id

  # Join table: tag categories that participate in a survey.
  create_table :survey_category_tags do |t|
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.references :category, null: false, foreign_key: { to_table: :categories, on_delete: :cascade }
      t.timestamps
    end
    add_index :survey_category_tags, %i[survey_id category_id], unique: true

  # Entity table: immutable audit log entries for survey actions.
  create_table :survey_audit_logs do |t|
      t.references :survey, foreign_key: { to_table: :surveys, on_delete: :nullify }
      t.references :admin, null: false, foreign_key: { to_table: :admins, primary_key: :admin_id, on_delete: :cascade }
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :survey_audit_logs, :created_at
    add_index :survey_audit_logs, :action

  # Entity table: high-level survey change summaries.
  create_table :survey_change_logs do |t|
      t.references :survey, foreign_key: { to_table: :surveys, on_delete: :nullify }
      t.references :admin, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :action, null: false
      t.text :description
      t.timestamps
    end
    add_index :survey_change_logs, :created_at

  # Entity table: logs high-level administrator actions for dashboards.
  create_table :admin_activity_logs do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :action, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :metadata, null: false, default: {}
      t.text :description
      t.timestamps
    end
    add_index :admin_activity_logs, %i[subject_type subject_id], name: "index_admin_activity_logs_on_subject"

  # Entity table: advisor feedback summaries for students.
  create_table :feedback do |t|
      t.references :student, null: false, foreign_key: { to_table: :students, primary_key: :student_id, on_delete: :cascade }
      t.references :advisor, null: false, foreign_key: { to_table: :advisors, primary_key: :advisor_id, on_delete: :cascade }
      t.references :category, null: false, foreign_key: { to_table: :categories, on_delete: :cascade }
      t.references :survey, null: false, foreign_key: { to_table: :surveys, on_delete: :cascade }
      t.references :question, foreign_key: { to_table: :questions }, index: true
      t.float :average_score
      t.string :comments
      t.timestamps
    end
    add_index :feedback, :survey_id

    backfill_mha_competency_sections
    backfill_mha_competency_tooltips
    backfill_program_target_levels
    backfill_mha_competency_feedback_flags
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "AlignSchemaWithTarget cannot be rolled back"
  end

  private

  def backfill_mha_competency_sections
    return if CATEGORY_NAMES.empty?

    MigrationSurveySection.reset_column_information
    MigrationCategory.reset_column_information

    say_with_time "Backfilling MHA competency survey sections" do
      survey_ids = MigrationCategory.where(name: CATEGORY_NAMES).distinct.pluck(:survey_id)
      survey_ids.each do |survey_id|
        section = MigrationSurveySection.find_or_create_by!(survey_id: survey_id, title: SECTION_TITLE) do |record|
          record.description = SECTION_DESCRIPTION
          record.position = next_section_position_for(survey_id)
        end

        MigrationCategory.where(survey_id: survey_id, name: CATEGORY_NAMES).update_all(survey_section_id: section.id)
      end
    end
  end

  def backfill_mha_competency_tooltips
    return if CATEGORY_NAMES.empty?

    MigrationCategory.reset_column_information
    MigrationQuestion.reset_column_information

    say_with_time "Backfilling tooltip text for MHA competency questions" do
      target_category_ids = MigrationCategory.left_joins(:survey_section)
                                             .where("survey_sections.title = ? OR categories.name IN (?)", SECTION_TITLE, CATEGORY_NAMES)
                                             .distinct
                                             .pluck(:id)

      if target_category_ids.empty?
        0
      else
        scope = MigrationQuestion.where(category_id: target_category_ids, tooltip_text: nil, question_type: "multiple_choice")
                                  .where.not(description: [nil, ""])

        updated_count = 0
        scope.find_in_batches(batch_size: 200) do |batch|
          batch.each do |question|
            question.update_columns(tooltip_text: question.description)
            updated_count += 1
          end
        end
        updated_count
      end
    end
  end

  def backfill_program_target_levels
    MigrationQuestion.reset_column_information

    say_with_time "Backfilling program target levels for MHA competency questions" do
      execute <<~SQL
        UPDATE questions
        SET program_target_level = 3
        FROM categories
        INNER JOIN survey_sections
          ON survey_sections.id = categories.survey_section_id
        WHERE questions.category_id = categories.id
          AND questions.program_target_level IS NULL
          AND questions.question_type IN ('multiple_choice', 'dropdown')
          AND LOWER(survey_sections.title) = LOWER('#{SECTION_TITLE}');
      SQL
    end
  end

  def backfill_mha_competency_feedback_flags
    MigrationQuestion.reset_column_information
    return unless MigrationQuestion.column_names.include?("has_feedback")

    say_with_time "Backfilling has_feedback for MHA competency parent questions" do
      execute <<~SQL
        UPDATE questions
        SET has_feedback = TRUE
        FROM categories
        INNER JOIN survey_sections
          ON survey_sections.id = categories.survey_section_id
        WHERE questions.category_id = categories.id
          AND questions.has_feedback = FALSE
          AND questions.parent_question_id IS NULL
          AND LOWER(survey_sections.title) = LOWER('#{SECTION_TITLE}');
      SQL
    end
  end

  def next_section_position_for(survey_id)
    (MigrationSurveySection.where(survey_id: survey_id).maximum(:position) || 0) + 1
  end
end