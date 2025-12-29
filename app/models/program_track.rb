# frozen_string_literal: true

# Database-backed program tracks (e.g., Residential, Executive).
#
# Tracks are seeded in db/seeds.rb and then referenced throughout the app.
class ProgramTrack < ApplicationRecord
  DEFAULT_TRACKS = [
    { key: "residential", name: "Residential", position: 10 },
    { key: "executive", name: "Executive", position: 20 }
  ].freeze

  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(:position, Arel.sql("LOWER(name) ASC")) }
  scope :active, -> { where(active: true) }

  def self.data_source_ready?
    connection.data_source_exists?(table_name)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end

  def self.seed_defaults!
    return unless data_source_ready?

    DEFAULT_TRACKS.each do |attrs|
      record = find_or_initialize_by(key: attrs[:key])
      record.name = attrs[:name]
      record.position = attrs[:position]
      record.active = true if record.active.nil?
      record.save!
    end
  end

  # @return [Hash{String=>String}] key => display name
  def self.tracks_hash
    if data_source_ready?
      rows = active.ordered.pluck(:key, :name)
      return rows.to_h if rows.any?
    end

    DEFAULT_TRACKS.map { |attrs| [ attrs[:key], attrs[:name] ] }.to_h
  rescue ActiveRecord::StatementInvalid
    DEFAULT_TRACKS.map { |attrs| [ attrs[:key], attrs[:name] ] }.to_h
  end

  # Accepts either the key ("residential"), the display name ("Residential"), or
  # a loosely formatted label (" residential ") and returns the canonical key.
  #
  # @return [String, nil]
  def self.canonical_key(value)
    text = value.to_s.strip
    return if text.blank?

    normalized = text.downcase

    # Fast path: direct key match.
    tracks = tracks_hash
    return normalized if tracks.key?(normalized)

    # Match by name.
    key = tracks.find { |_k, name| name.to_s.strip.casecmp?(text) }&.first
    key.presence
  end

  def self.name_for_key(key)
    canonical = canonical_key(key)
    return if canonical.blank?

    tracks_hash[canonical]
  end

  def self.names
    tracks_hash.values
  end

  def self.keys
    tracks_hash.keys
  end
end
