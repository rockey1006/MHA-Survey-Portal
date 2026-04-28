class Competency < ApplicationRecord
  belongs_to :domain

  validates :title, presence: true, uniqueness: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { joins(:domain).order("domains.position ASC", :position, :title) }
end
