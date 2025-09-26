class Question < ApplicationRecord
  belongs_to :competency, optional: true
  has_many :question_responses, foreign_key: :question_id, dependent: :destroy

  # question_type could be 'text', 'select', 'radio', 'checkbox'
  # answer_options stored as serialized array in DB or as JSON string; existing schema comment says 'Answer Options: String List'
end
