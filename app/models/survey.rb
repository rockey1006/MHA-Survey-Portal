# Survey definition composed of categories and questions, with track-based
# assignments and change logging.
class Survey < ApplicationRecord
  # Predefined track labels administrators can assign.
  TRACK_OPTIONS = [
    "Residential",
    "Executive",
  ].freeze

  belongs_to :creator, class_name: "User", foreign_key: :created_by_id, optional: true

  has_many :categories, inverse_of: :survey, dependent: :destroy
  has_many :questions, through: :categories
  has_many :survey_assignments, inverse_of: :survey, dependent: :destroy
  has_many :survey_change_logs, dependent: :nullify
  has_many :feedbacks, foreign_key: :survey_id, class_name: "Feedback", dependent: :destroy
  has_many :student_questions, through: :questions

  accepts_nested_attributes_for :categories, allow_destroy: true

  validates :title, presence: true
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
    survey_assignments.order(:track).pluck(:track)
  end

  # Replaces the survey's track assignments with the provided list.
  #
  # @param tracks [Enumerable<String>]
  # @return [void]
  def assign_tracks!(tracks)
    normalized = normalize_track_values(tracks)

    transaction do
      survey_assignments.where.not(track: normalized).destroy_all
      normalized.each do |track|
        survey_assignments.find_or_create_by!(track: track)
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
        text = value.to_s
        if text.length > 255
          text[0..254]
        else
          text
        end
      end
      .uniq
      .sort
  end
end
