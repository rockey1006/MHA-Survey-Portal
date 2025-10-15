class CategoryQuestion < ApplicationRecord
  belongs_to :category
  belongs_to :question

  validates :question_id, uniqueness: { scope: :category_id }
end
