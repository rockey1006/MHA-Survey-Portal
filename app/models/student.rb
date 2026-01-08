# Profile for student users, including survey responses and advisor
# relationships.
class Student < ApplicationRecord
  self.primary_key = :student_id

  UIN_FORMAT = /\A\d{9}\z/.freeze

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
  validates :track,
            inclusion: { in: ->(_student) { ProgramTrack.keys } },
            allow_blank: true,
            on: :profile_completion
  # Program year is stored as a cohort/graduation year (e.g., 2026, 2027).
  validates :program_year, presence: true, on: :profile_completion
  validates :program_year, numericality: { only_integer: true, greater_than_or_equal_to: 2026, less_than_or_equal_to: 3000 }, allow_nil: true

  after_commit :auto_assign_track_survey, if: -> { saved_change_to_track? || saved_change_to_program_year? }

  # Checks if the student has completed their profile setup
  #
  # @return [Boolean]
  def profile_complete?
    user.name.present? && uin.present? && major.present? && track.present? && program_year.present?
  end

  # Backwards-compat: treat legacy class_of as program_year.
  # (The DB column may be removed, but some code paths/tests still call class_of.)
  def class_of
    program_year
  end

  def class_of=(value)
    self.program_year = value
  end

  # @return [String] the student's preferred full name
  def full_name
    user.full_name
  end

  # Database stores the track label (e.g., "Residential").
  # Public API returns the canonical key (e.g., "residential") to preserve
  # behavior previously provided by the enum.
  def track
    ProgramTrack.canonical_key(self[:track])
  end

  # Accepts either a key ("residential") or label ("Residential") and stores
  # the canonical label in the DB.
  def track=(value)
    key = ProgramTrack.canonical_key(value)
    self[:track] = key.present? ? ProgramTrack.name_for_key(key) : value.to_s.strip.presence
  end

  # Compatibility shim for code that used the enum mapping.
  # @return [Hash{String=>String}] key => label
  def self.tracks
    ProgramTrack.tracks_hash
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
