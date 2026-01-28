# frozen_string_literal: true

class AddSurveyTitleSnapshotToSurveyChangeLogs < ActiveRecord::Migration[7.0]
  def change
    add_column :survey_change_logs, :survey_title_snapshot, :string
  end
end
