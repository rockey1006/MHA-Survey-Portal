# frozen_string_literal: true

# Maps a survey to a specific program (track), cohort year (class_of), and stage.
# These rows drive auto-assignment and provide cohort-specific availability windows.
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

  scope :available_at, lambda { |time|
    where("survey_offerings.available_from IS NULL OR survey_offerings.available_from <= ?", time)
      .where("survey_offerings.available_until IS NULL OR survey_offerings.available_until >= ?", time)
  }

  def self.data_source_ready?
    connection.data_source_exists?(table_name)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end

  def self.for_student(track_key:, class_of:, assignment_group: nil)
    return none if track_key.blank? || class_of.blank?

    track_label = ProgramTrack.name_for_key(track_key) || track_key.to_s

    reference_time = Time.zone&.now || Time.current

    scope = active
      .where("LOWER(survey_offerings.track) = ?", track_label.to_s.downcase)
      .where("class_of IS NULL OR class_of = ?", class_of.to_i)
      .available_at(reference_time)
      .joins(survey: :program_semester)
      .merge(Survey.active)
      .where(program_semesters: { current: true })

    group = assignment_group.to_s.strip
    if group.present?
      grouped = scope.where(assignment_group: group)
      return grouped if grouped.exists?

      return scope.where(assignment_group: nil)
    end

    scope.where(assignment_group: nil)
  end

  private

  def availability_window_order
    return if available_from.blank? || available_until.blank?
    return if available_from <= available_until

    errors.add(:available_until, "must be after Available from")
  end
end
