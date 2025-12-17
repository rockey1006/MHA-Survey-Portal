# Survey definition composed of categories and questions, with track-based
# assignments and change logging.
class Survey < ApplicationRecord
  # Predefined track labels administrators can assign.
  TRACK_OPTIONS = [
    "Residential",
    "Executive"
  ].freeze

  belongs_to :creator, class_name: "User", foreign_key: :created_by_id, optional: true

  has_many :categories, inverse_of: :survey, dependent: :destroy
  has_one :legend, class_name: "SurveyLegend", inverse_of: :survey, dependent: :destroy
  has_many :sections,
           class_name: "SurveySection",
           inverse_of: :survey,
           dependent: :destroy
  has_many :questions, through: :categories
  has_many :track_assignments, class_name: "SurveyTrackAssignment", inverse_of: :survey, dependent: :destroy
  has_many :survey_assignments, inverse_of: :survey, dependent: :destroy
  has_many :survey_change_logs, dependent: :nullify
  has_many :feedbacks, foreign_key: :survey_id, class_name: "Feedback", dependent: :destroy
  has_many :student_questions, through: :questions

  accepts_nested_attributes_for :categories, allow_destroy: true
  accepts_nested_attributes_for :legend, update_only: true, allow_destroy: true
  accepts_nested_attributes_for :sections, allow_destroy: true

  before_validation :normalize_title_and_semester

  validates :title,
            presence: true,
            uniqueness: {
              scope: :semester,
              case_sensitive: false,
              message: "already exists for this semester"
            }
  validates :semester, presence: true
  validates :is_active, inclusion: { in: [ true, false ] }
  validate :validate_category_structure

  # @return [ActiveRecord::Relation<Survey>] newest surveys first
  scope :ordered, -> { order(created_at: :desc) }
  # @return [ActiveRecord::Relation<Survey>] surveys currently active
  scope :active, -> { where(is_active: true) }
  # @return [ActiveRecord::Relation<Survey>] surveys marked inactive
  scope :archived, -> { where(is_active: false) }

  # @return [Array<String>] unique tracks assigned to the survey
  def track_list
    track_assignments.order(:track).pluck(:track).uniq
  end

  def self.canonical_track(value)
    text = value.to_s.strip
    return if text.blank?

    TRACK_OPTIONS.find { |option| option.casecmp?(text) }
  end

  # Replaces the survey's track assignments with the provided list.
  #
  # @param tracks [Enumerable<String>]
  # @return [void]
  def assign_tracks!(tracks)
    normalized = normalize_track_values(tracks)

    transaction do
      track_assignments.where.not(track: normalized).destroy_all
      normalized.each do |track|
        track_assignments.find_or_create_by!(track: track)
      end
    end
  end

  # Records an administrative change to the survey.
  #
  # @param admin [Admin]
  # @param action [String]
  # @param description [String, nil]
  # @return [SurveyChangeLog]
  def log_change!(admin:, action:, description: nil)
    survey_change_logs.create!(admin: admin, action: action, description: description)
  end

  private

  def validate_category_structure
    active_categories = categories.reject(&:marked_for_destruction?)
    if active_categories.empty?
      errors.add(:base, "Add at least one category to the survey")
      return
    end

    active_categories.each do |category|
      next if category.questions.reject(&:marked_for_destruction?).any?

      errors.add(:base, "Each category must include at least one question")
    end
  end

  def normalize_track_values(values)
    Array(values)
      .flatten
      .map { |value| value.is_a?(String) ? value.strip : value }
      .reject(&:blank?)
      .map do |value|
        canonical = Survey.canonical_track(value)
        next canonical if canonical.present?

        text = value.to_s
        text.length > 255 ? text[0..254] : text
      end
      .reject(&:blank?)
      .uniq
      .sort
  end

  def normalize_title_and_semester
    self.title = title.to_s.strip.squeeze(" ")

    normalized_semester = semester.to_s.strip
    if normalized_semester.present?
      tokens = normalized_semester.split(/\s+/)
      self.semester = tokens.map.with_index do |token, index|
        if token.match?(/^\d+$/)
          token
        elsif index.zero?
          token.capitalize
        else
          token
        end
      end.join(" ")
    else
      self.semester = normalized_semester
    end
  end
end
