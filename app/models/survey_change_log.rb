class SurveyChangeLog < ApplicationRecord
  ACTIONS = %w[create update assign archive activate delete preview].freeze

  belongs_to :survey, optional: true
  belongs_to :admin, class_name: "User"

  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }
end
