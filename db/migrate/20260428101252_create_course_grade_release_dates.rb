class CreateCourseGradeReleaseDates < ActiveRecord::Migration[8.0]
  def change
    create_table :course_grade_release_dates do |t|
      t.references :survey, null: false, foreign_key: true, index: { unique: true }
      t.datetime :release_at

      t.timestamps
    end

    add_index :course_grade_release_dates, :release_at
  end
end
