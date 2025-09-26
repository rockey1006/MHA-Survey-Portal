class Competency < ApplicationRecord
  belongs_to :survey, optional: true
  has_many :questions, dependent: :destroy
  has_many :competency_responses, dependent: :destroy
end
