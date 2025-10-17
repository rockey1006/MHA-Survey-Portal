# Historical log entries describing survey changes for auditing.
class SurveyAuditLog < ApplicationRecord
  # Allowed action types recorded in the audit log.
  ACTIONS = %w[create update delete group_update preview].freeze

  belongs_to :survey, optional: true
  belongs_to :admin, class_name: "Admin", foreign_key: :admin_id, primary_key: :admin_id

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :metadata, presence: true

  # @return [ActiveRecord::Relation<SurveyAuditLog>] newest logs first
  scope :recent_first, -> { order(created_at: :desc) }
end
