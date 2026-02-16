class CreateAdvisorFeedbackSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :advisor_feedback_submissions do |t|
      t.bigint :student_id, null: false
      t.bigint :survey_id, null: false
      t.bigint :advisor_id, null: false
      t.datetime :last_saved_at
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :advisor_feedback_submissions,
              %i[student_id survey_id advisor_id],
              unique: true,
              name: "index_feedback_submissions_on_student_survey_advisor"
    add_index :advisor_feedback_submissions, :submitted_at

    add_foreign_key :advisor_feedback_submissions, :students,
                    column: :student_id,
                    primary_key: :student_id
    add_foreign_key :advisor_feedback_submissions, :surveys,
                    column: :survey_id
    add_foreign_key :advisor_feedback_submissions, :advisors,
                    column: :advisor_id,
                    primary_key: :advisor_id
  end
end
