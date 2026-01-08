# Logical grouping for survey categories, used to inject instructional headers.
class SurveySection < ApplicationRecord
  MHA_COMPETENCY_SECTION_TITLE = "MHA Competency Self-Assessment".freeze
  DEFAULT_TITLE = "Untitled section".freeze
  attr_accessor :form_uid

  attribute :position, :integer, default: nil
  belongs_to :survey
  has_many :categories,
           class_name: "Category",
           foreign_key: :survey_section_id,
           inverse_of: :section,
           dependent: :nullify

  validates :title, presence: true
  validates :position,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  scope :ordered, -> { order(:position, :id) }

  before_validation :normalize_title
  before_validation :assign_position

  # True when this section represents the standard MHA competency block.
  # @return [Boolean]
  def mha_competency?
    title.to_s.strip.casecmp?(MHA_COMPETENCY_SECTION_TITLE)
  end

  private

  def assign_position
    return if position.present?

    if survey.blank?
      self.position = 0
      return
    end

    highest_position = survey.sections.where.not(id: id).maximum(:position)
    self.position = highest_position ? highest_position + 1 : 0
  end

  def normalize_title
    self.title = title.to_s.strip
    self.title = DEFAULT_TITLE if title.blank?
  end
end
