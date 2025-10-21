class RemoveUniqueIndexOnFeedbackSurveyId < ActiveRecord::Migration[8.0]
  def change
    # Remove the unique index that prevents multiple feedback rows per survey.
    # If the index doesn't exist (for example in older test DBs), ignore errors.
    if index_exists?(:feedback, :survey_id, name: "index_feedback_on_survey_id")
      remove_index :feedback, name: "index_feedback_on_survey_id"
    end

    # Re-add a non-unique index for faster lookups.
    unless index_exists?(:feedback, :survey_id, name: "index_feedback_on_survey_id")
      add_index :feedback, :survey_id, name: "index_feedback_on_survey_id"
    end
  end
end
