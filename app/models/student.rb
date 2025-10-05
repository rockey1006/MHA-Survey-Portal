class Student < ApplicationRecord
  self.primary_key = :student_id

  enum :track, { residential: "Residential", executive: "Executive" }, prefix: true

  belongs_to :user, foreign_key: :student_id, primary_key: :user_id, inverse_of: :student_profile
  belongs_to :advisor, optional: true
  has_many :survey_responses, foreign_key: :student_id, dependent: :destroy

  delegate :email, :email=, :name, :name=, :avatar_url, :avatar_url=, to: :user

  validates :uin, uniqueness: true, allow_nil: true

  def full_name
    user.full_name
  end

  def save(*args, &block)
    user.save! if user&.changed?
    super
  end

  def save!(*args, &block)
    user.save! if user&.changed?
    super
  end
end
