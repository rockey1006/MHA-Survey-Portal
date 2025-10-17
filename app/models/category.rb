class Category < ApplicationRecord
  belongs_to :survey
  has_many :questions, inverse_of: :category, dependent: :destroy
  has_many :feedbacks, foreign_key: :category_id, class_name: "Feedback"

  accepts_nested_attributes_for :questions, allow_destroy: true

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
