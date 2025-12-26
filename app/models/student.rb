# Profile for student users, including survey responses and advisor
# relationships.
class Student < ApplicationRecord
  self.primary_key = :student_id

  UIN_FORMAT = /\A\d{9}\z/.freeze

  enum :track, { residential: "Residential", executive: "Executive" }, prefix: true

  belongs_to :user, foreign_key: :student_id, primary_key: :id, inverse_of: :student_profile
  belongs_to :advisor, optional: true
  has_many :student_questions, dependent: :destroy
  has_many :questions, through: :student_questions
  has_many :feedbacks, foreign_key: :student_id
  has_many :survey_assignments, foreign_key: :student_id, primary_key: :student_id, dependent: :destroy

  delegate :email, :email=, :name, :name=, :avatar_url, :avatar_url=, to: :user

  before_validation :normalize_uin

  validates :uin, uniqueness: true, allow_nil: true
  validates :uin, presence: true, on: :profile_completion
  validates :uin, format: { with: UIN_FORMAT, message: "must be exactly 9 digits" }, allow_nil: true
  validates :major, presence: true, on: :profile_completion
  validates :track, presence: true, on: :profile_completion
  validates :program_year, presence: true, on: :profile_completion
  validates :program_year, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10 }, allow_nil: true

  after_commit :auto_assign_track_survey, if: -> { saved_change_to_track? || saved_change_to_program_year? }

  # Checks if the student has completed their profile setup
  #
  # @return [Boolean]
  def profile_complete?
    user.name.present? && uin.present? && major.present? && track.present?
  end

  # @return [String] the student's preferred full name
  def full_name
    user.full_name
  end

  # Saves the student and any pending user changes.
  #
  # @return [Boolean]
  def save(*args, **kwargs, &block)
    user.save! if user&.changed?
    super(*args, **kwargs, &block)
  end

  # Saves the student and underlying user, raising on failure.
  #
  # @return [Boolean]
  def save!(*args, **kwargs, &block)
    user.save! if user&.changed?
    super(*args, **kwargs, &block)
  end

  private

  def normalize_uin
    digits = uin.to_s.gsub(/\D+/, "")
    self.uin = digits.presence
  end

  def auto_assign_track_survey
    SurveyAssignments::AutoAssigner.call(student: self)
  rescue StandardError => e
    Rails.logger.error("Track auto-assign failed for student #{student_id}: #{e.class}: #{e.message}")
  end
end
