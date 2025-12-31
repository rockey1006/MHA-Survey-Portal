# Stores global, app-wide configuration values.
#
# This is intentionally simple (key/value) so we can add more settings later
# without changing schema each time.
class SiteSetting < ApplicationRecord
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
  end
end
