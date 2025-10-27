# Profile for student users, including survey responses and advisor
# relationships.
class Student < ApplicationRecord
  self.primary_key = :student_id

  enum :track, { residential: "Residential", executive: "Executive" }, prefix: true

  belongs_to :user, foreign_key: :student_id, primary_key: :id, inverse_of: :student_profile
  belongs_to :advisor, optional: true
  has_many :student_questions, dependent: :destroy
  has_many :questions, through: :student_questions
  has_many :feedbacks, foreign_key: :student_id
  has_many :survey_assignments, foreign_key: :student_id, primary_key: :student_id, dependent: :destroy

  delegate :email, :email=, :name, :name=, :avatar_url, :avatar_url=, to: :user

  validates :uin, uniqueness: true, allow_nil: true

  # @return [String] the student's preferred full name
  def full_name
    user.full_name
  end

  # Saves the student and any pending user changes.
  #
  # @return [Boolean]
  def save(*args, &block)
    user.save! if user&.changed?
    super
  end

  # Saves the student and underlying user, raising on failure.
  #
  # @return [Boolean]
  def save!(*args, &block)
    user.save! if user&.changed?
    super
  end
end
