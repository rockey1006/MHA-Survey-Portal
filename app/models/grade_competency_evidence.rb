class GradeCompetencyEvidence < ApplicationRecord
  belongs_to :grade_import_batch
  belongs_to :grade_import_file
  belongs_to :student, foreign_key: :student_id, primary_key: :student_id

  validates :competency_title, presence: true
  validates :raw_grade, presence: true
  validates :source_key, :import_fingerprint, presence: true
  validates :import_fingerprint, uniqueness: true
  validates :mapped_level, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :course_target_level, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
end
