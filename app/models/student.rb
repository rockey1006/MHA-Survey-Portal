
class Student < ApplicationRecord
  enum :track, { residential: "residential", executive: "executive" }, prefix: true
  has_many :survey_responses
end

class Survey < ApplicationRecord
  has_many :survey_responses
end
