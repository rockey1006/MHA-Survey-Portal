class Survey < ApplicationRecord
  validates :title, presence: true
  validates :semester, presence: true
  validate :completion_date_after_assigned_date
  
  has_many :competencies, dependent: :destroy
  # Expose questions through competencies so views/controllers can access them directly
  has_many :questions, through: :competencies
  has_many :survey_responses, dependent: :destroy
  # convenience: students through survey_responses
  has_many :students, through: :survey_responses

  private

  def completion_date_after_assigned_date
    return unless assigned_date.present? && completion_date.present?
    
    if completion_date < assigned_date
      errors.add(:completion_date, "must be after assigned date")
    end
  end
end
