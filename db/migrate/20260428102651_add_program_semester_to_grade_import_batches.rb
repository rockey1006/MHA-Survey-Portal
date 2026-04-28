class AddProgramSemesterToGradeImportBatches < ActiveRecord::Migration[8.0]
  def change
    add_reference :grade_import_batches, :program_semester, foreign_key: true, null: true
  end
end
