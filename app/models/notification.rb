class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true

  scope :unread, -> { where(read_at: nil) }

  validates :title, presence: true
  validates :notifiable_type, presence: true
  validates :notifiable_id, presence: true

  def mark_read!
    update!(read_at: Time.current)
  end
end
