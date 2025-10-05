class Category < ApplicationRecord
  belongs_to :survey
  has_many :questions, foreign_key: :category_id, dependent: :destroy
  has_many :feedbacks, foreign_key: :category_id, class_name: "Feedback"

  validates :name, presence: true
end
