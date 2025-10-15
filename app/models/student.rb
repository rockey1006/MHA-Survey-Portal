class Student < ApplicationRecord
  self.primary_key = :student_id

  enum :track, { residential: "Residential", executive: "Executive" }, prefix: true

  belongs_to :user, foreign_key: :student_id, primary_key: :id, inverse_of: :student_profile
  belongs_to :advisor, optional: true
  has_many :student_questions, dependent: :destroy
  has_many :questions, through: :student_questions
  has_many :feedbacks, foreign_key: :student_id

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
