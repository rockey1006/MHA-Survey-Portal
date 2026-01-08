# frozen_string_literal: true

class CompetencyTargetLevel < ApplicationRecord
  belongs_to :program_semester

  validates :program_semester_id, presence: true
  validates :track, presence: true
  validates :competency_title, presence: true
  validates :target_level, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }

  validates :track, inclusion: { in: ->(_record) { ProgramTrack.names } }, allow_blank: true

  validates :class_of, numericality: { only_integer: true, greater_than_or_equal_to: 2026, less_than_or_equal_to: 3000 }, allow_nil: true
  validates :competency_title, uniqueness: { scope: %i[program_semester_id track program_year class_of] }
end
