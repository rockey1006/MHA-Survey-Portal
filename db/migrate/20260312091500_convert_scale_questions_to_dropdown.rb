class ConvertScaleQuestionsToDropdown < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE questions
      SET question_type = 'dropdown'
      WHERE question_type = 'scale'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely restore scale question types after conversion to dropdown"
  end
end
