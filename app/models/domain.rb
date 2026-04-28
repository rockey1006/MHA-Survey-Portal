class Domain < ApplicationRecord
  has_many :competencies, -> { order(:position, :title) }, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :name) }
end
