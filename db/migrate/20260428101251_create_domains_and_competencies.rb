class CreateDomainsAndCompetencies < ActiveRecord::Migration[8.0]
  DOMAIN_COMPETENCIES = {
    "Health Care Environment and Community" => [
      "Public and Population Health Assessment",
      "Delivery, Organization, and Financing of Health Services and Health Systems",
      "Policy Analysis",
      "Legal & Ethical Bases for Health Services and Health Systems"
    ],
    "Leadership Skills" => [
      "Ethics, Accountability, and Self-Assessment",
      "Organizational Dynamics",
      "Problem Solving, Decision Making, and Critical Thinking",
      "Team Building and Collaboration"
    ],
    "Management Skills" => [
      "Strategic Planning",
      "Business Planning",
      "Communication",
      "Financial Management",
      "Performance Improvement",
      "Project Management"
    ],
    "Analytic and Technical Skills" => [
      "Systems Thinking",
      "Data Analysis and Information Management",
      "Quantitative Methods for Health Services Delivery"
    ]
  }.freeze

  def up
    create_table :domains do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :domains, :name, unique: true
    add_index :domains, :position

    create_table :competencies do |t|
      t.references :domain, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :competencies, :title, unique: true
    add_index :competencies, [ :domain_id, :position ]

    seed_domains_and_competencies

    create_table :course_grade_release_dates do |t|
      t.references :program_semester, null: false, foreign_key: true
      t.datetime :release_date

      t.timestamps
    end

    add_index :course_grade_release_dates,
              :program_semester_id,
              unique: true,
              name: "index_course_release_dates_on_program_semester_unique"
    add_index :course_grade_release_dates, :release_date

    add_reference :grade_import_batches, :program_semester, foreign_key: true, null: true
    add_column :grade_competency_evidences, :course_target_level, :integer
    add_column :grade_import_pending_rows, :course_target_level, :integer
  end

  def down
    remove_column :grade_import_pending_rows, :course_target_level if column_exists?(:grade_import_pending_rows, :course_target_level)
    remove_column :grade_competency_evidences, :course_target_level if column_exists?(:grade_competency_evidences, :course_target_level)
    remove_reference :grade_import_batches, :program_semester, foreign_key: true if column_exists?(:grade_import_batches, :program_semester_id)
    drop_table :course_grade_release_dates if table_exists?(:course_grade_release_dates)
    drop_table :competencies if table_exists?(:competencies)
    drop_table :domains if table_exists?(:domains)
  end

  private

  def seed_domains_and_competencies
    DOMAIN_COMPETENCIES.each_with_index do |(domain_name, titles), domain_index|
      domain_id = insert_domain(domain_name, domain_index + 1)

      titles.each_with_index do |title, competency_index|
        insert_competency(domain_id, title, competency_index + 1)
      end
    end
  end

  def insert_domain(name, position)
    quoted_name = connection.quote(name)
    now = "CURRENT_TIMESTAMP"

    execute <<~SQL.squish
      INSERT INTO domains (name, position, created_at, updated_at)
      VALUES (#{quoted_name}, #{position}, #{now}, #{now})
      ON CONFLICT (name) DO UPDATE
      SET position = EXCLUDED.position,
          updated_at = #{now}
    SQL

    select_value("SELECT id FROM domains WHERE name = #{quoted_name}")
  end

  def insert_competency(domain_id, title, position)
    quoted_title = connection.quote(title)
    now = "CURRENT_TIMESTAMP"

    execute <<~SQL.squish
      INSERT INTO competencies (domain_id, title, position, created_at, updated_at)
      VALUES (#{domain_id}, #{quoted_title}, #{position}, #{now}, #{now})
      ON CONFLICT (title) DO UPDATE
      SET domain_id = EXCLUDED.domain_id,
          position = EXCLUDED.position,
          updated_at = #{now}
    SQL
  end
end
