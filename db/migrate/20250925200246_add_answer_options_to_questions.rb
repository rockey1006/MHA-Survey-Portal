class AddAnswerOptionsToQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :answer_options, :string, array: true, default: []
  end
end
