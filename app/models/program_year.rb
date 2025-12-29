# Database-backed program year options (e.g., Year 1, Year 2).
class ProgramYear < ApplicationRecord
  DEFAULT_YEARS = [
    { value: 1, position: 10 },
    { value: 2, position: 20 }
  ].freeze

  validates :value, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :value, uniqueness: true

  scope :ordered, -> { order(:position, :value) }
  scope :active, -> { where(active: true) }

  def self.data_source_ready?
    connection.data_source_exists?(table_name)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end

  def self.seed_defaults!
    return unless data_source_ready?

    DEFAULT_YEARS.each do |attrs|
      record = find_or_initialize_by(value: attrs[:value])
      record.position = attrs[:position]
      record.active = true if record.active.nil?
      record.save!
    end
  end

  # @return [Array<Integer>]
  def self.values
    if data_source_ready?
      rows = active.ordered.pluck(:value)
      return rows if rows.any?
    end

    DEFAULT_YEARS.map { |attrs| attrs[:value] }
  rescue ActiveRecord::StatementInvalid
    DEFAULT_YEARS.map { |attrs| attrs[:value] }
  end

  # @return [Array<Array(String, Integer)>] [label, value]
  def self.options_for_select
    values.map { |year| ["Year #{year}", year] }
  end
end
