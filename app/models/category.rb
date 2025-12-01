# Grouping for survey questions, tied to a parent survey.
class Category < ApplicationRecord
  attr_accessor :section_form_uid
  belongs_to :survey
  belongs_to :section,
             class_name: "SurveySection",
             foreign_key: :survey_section_id,
             optional: true
  has_many :questions, inverse_of: :category, dependent: :destroy
  has_many :feedbacks, foreign_key: :category_id, class_name: "Feedback"

  accepts_nested_attributes_for :questions, allow_destroy: true

  validates :name, presence: true
  validate :section_matches_survey

  # @return [ActiveRecord::Relation<Category>] categories ordered alphabetically
  scope :ordered, -> { order(:name) }

  private

  def section_matches_survey
    return if section.blank? || survey_id.blank?

    errors.add(:section, "must belong to the same survey") if section.survey_id != survey_id
  end
end
