class Advisor < ApplicationRecord
  self.primary_key = :advisor_id

  belongs_to :user, foreign_key: :advisor_id, primary_key: :id, inverse_of: :advisor_profile
  has_many :advisees, class_name: "Student", foreign_key: :advisor_id, dependent: :destroy
  has_many :student_questions, foreign_key: :advisor_id, dependent: :nullify
  has_many :feedbacks, foreign_key: :advisor_id
  delegate :email, :email=, :name, :name=, :avatar_url, :avatar_url=, to: :user

  def display_name
    name.presence || email
  end

  def role
    user.role
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
