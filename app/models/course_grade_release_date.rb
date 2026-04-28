class CourseGradeReleaseDate < ApplicationRecord
  belongs_to :program_semester

  validates :program_semester_id, presence: true, uniqueness: true

  scope :released, -> { where("release_date IS NULL OR release_date <= ?", Time.current) }
  scope :embargoed, -> { where("release_date > ?", Time.current) }

  def released?
    release_date.blank? || release_date <= Time.current
  end

  def status_label
    released? ? "Visible" : "Embargoed"
  end
end
