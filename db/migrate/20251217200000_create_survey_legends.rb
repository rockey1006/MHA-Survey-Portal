class CreateSurveyLegends < ActiveRecord::Migration[7.1]
  MHA_COMPETENCY_SECTION_TITLE = "MHA Competency Self-Assessment".freeze

  def up
    create_table :survey_legends do |t|
      t.references :survey, null: false, foreign_key: true, index: { unique: true }
      t.string :title
      t.text :body, null: false

      t.timestamps
    end

    add_column :questions, :program_target_level, :integer

    execute <<~SQL
      UPDATE questions
      SET program_target_level = 3
      FROM categories
      INNER JOIN survey_sections
        ON survey_sections.id = categories.survey_section_id
      WHERE questions.category_id = categories.id
        AND questions.program_target_level IS NULL
        AND questions.question_type IN ('multiple_choice', 'dropdown')
        AND LOWER(survey_sections.title) = LOWER('#{MHA_COMPETENCY_SECTION_TITLE}');
    SQL
  end

  def down
    remove_column :questions, :program_target_level
    drop_table :survey_legends
  end
end
