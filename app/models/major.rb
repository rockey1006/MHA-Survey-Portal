# Represents an available program major/program selection for student profiles.
class Major < ApplicationRecord
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_name

  private

  def normalize_name
    self.name = name.to_s.strip.presence
  end
end
