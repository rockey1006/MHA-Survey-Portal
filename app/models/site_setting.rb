# Stores global, app-wide configuration values.
#
# This is intentionally simple (key/value) so we can add more settings later
# without changing schema each time.
class SiteSetting < ApplicationRecord
  COURSE_COMPETENCY_RULE_KEY = "course_competency_rule"

  validates :key, presence: true, uniqueness: true

  class << self
    def get(key, default = nil)
      record = find_by(key: key.to_s)
      return default if record.nil?
      record.value
    end

    def set(key, value)
      record = find_or_initialize_by(key: key.to_s)
      record.value = value.nil? ? nil : value.to_s
      record.save!
      record.value
    end

    def maintenance_enabled?
      ActiveModel::Type::Boolean.new.cast(get("maintenance_enabled", "false"))
    end

    def set_maintenance_enabled!(enabled)
      set("maintenance_enabled", ActiveModel::Type::Boolean.new.cast(enabled))
    end

    def course_competency_rule
      CourseCompetencyRule.normalize(get(COURSE_COMPETENCY_RULE_KEY, CourseCompetencyRule::DEFAULT_RULE))
    end

    def set_course_competency_rule!(rule)
      normalized_rule = CourseCompetencyRule.normalize(rule)
      set(COURSE_COMPETENCY_RULE_KEY, normalized_rule)
      normalized_rule
    end
  end
end
