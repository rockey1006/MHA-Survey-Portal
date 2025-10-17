# Polymorphic notifications delivered to users and profiles.
class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true

  # @return [ActiveRecord::Relation<Notification>] unread notifications
  scope :unread, -> { where(read_at: nil) }

  validates :title, presence: true
  validates :notifiable_type, presence: true
  validates :notifiable_id, presence: true

  # Marks the notification as read by setting the timestamp.
  #
  # @return [Boolean]
  def mark_read!
    update!(read_at: Time.current)
  end
end
