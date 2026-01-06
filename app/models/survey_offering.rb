# frozen_string_literal: true

# Maps a survey to a specific program (track), cohort year (class_of), and stage.
# These rows drive auto-assignment and provide cohort-specific due dates.
class SurveyOffering < ApplicationRecord
  STAGES = %w[initial midpoint final].freeze

  belongs_to :survey

  validates :track, presence: true
  validates :stage, presence: true, inclusion: { in: STAGES }
  validates :class_of,
           numericality: { only_integer: true, greater_than_or_equal_to: 2026, less_than_or_equal_to: 3000 },
            allow_nil: true

  validate :availability_window_order

  scope :active, -> { where(active: true) }

  def self.data_source_ready?
    connection.data_source_exists?(table_name)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end

  def self.for_student(track_key:, class_of:)
    return none if track_key.blank? || class_of.blank?

    track_label = ProgramTrack.name_for_key(track_key) || track_key.to_s

    active
      .where("LOWER(track) = ?", track_label.to_s.downcase)
      .where("class_of IS NULL OR class_of = ?", class_of.to_i)
  end

  private

  def availability_window_order
    return if available_from.blank? || available_until.blank?
    return if available_from <= available_until

    errors.add(:available_until, "must be after Available from")
  end
end
