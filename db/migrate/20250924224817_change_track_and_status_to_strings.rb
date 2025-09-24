class ChangeTrackAndStatusToStrings < ActiveRecord::Migration[8.0]
  def change
    # For students table
    change_column :students, :track, :string

    # For survey_responses table
    change_column :survey_responses, :status, :string
  end
end
