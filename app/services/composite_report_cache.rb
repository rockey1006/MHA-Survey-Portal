# frozen_string_literal: true

require "json"
require "fileutils"
require "digest"

# Disk-backed cache for composite assessment PDFs. Entries are stored on the
# ephemeral filesystem under tmp/composite_reports so large PDF payloads do not
# linger in Ruby heap memory. Each entry tracks its fingerprint, expiration,
# and last-access time so we can enforce TTL and a simple LRU eviction policy.
class CompositeReportCache
  CACHE_DIR = Rails.root.join("tmp", "composite_reports")
  MAX_ENTRIES = Integer(ENV.fetch("COMPOSITE_REPORT_CACHE_MAX_ENTRIES", 50))
  MAX_BYTES = Integer(ENV.fetch("COMPOSITE_REPORT_CACHE_MAX_BYTES", 250.megabytes))

  Result = Struct.new(:path, :cached?, :size_bytes, keyword_init: true)

  class << self
    # Fetches a cached PDF path when the fingerprint matches, or yields to
    # generate a new artifact which is then persisted on disk.
    #
    # @param key [String]
    # @param fingerprint [String]
    # @param ttl [ActiveSupport::Duration]
    # @yieldreturn [#path, String, nil] source PDF file path/object
    # @return [Result, nil]
    def fetch(key, fingerprint, ttl: 6.hours, &block)
      instance.fetch(key, fingerprint, ttl:, &block)
    end

    def reset!
      instance.reset!
    end

    private

    def instance
      @instance ||= new
    end
  end

  def initialize
    FileUtils.mkdir_p(CACHE_DIR)
    @mutex = Mutex.new
  end

  def fetch(key, fingerprint, ttl: 6.hours)
    safe_key = safe_name(key)
    @mutex.synchronize { cleanup_expired! }

    if (entry = read_entry(safe_key)) && entry[:fingerprint] == fingerprint && !expired?(entry)
      touch_entry(safe_key, entry)
      return Result.new(path: entry[:path], cached?: true, size_bytes: entry[:size])
    end

    generated = yield
    return nil unless generated

    source_path = resolve_path(generated)
    return nil unless source_path && File.exist?(source_path)

    persisted_entry = @mutex.synchronize do
      persist_entry(safe_key, fingerprint, source_path, ttl)
      enforce_limits!
      read_entry(safe_key)
    end

    return nil unless persisted_entry

    Result.new(path: persisted_entry[:path], cached?: false, size_bytes: persisted_entry[:size])
  end

  def reset!
    FileUtils.rm_rf(CACHE_DIR)
    FileUtils.mkdir_p(CACHE_DIR)
  end

  private

  def resolve_path(source)
    return source.path if source.respond_to?(:path)
    source.to_s
  end

  def safe_name(key)
    digest = Digest::SHA256.hexdigest(key.to_s)
    prefix = key.to_s.gsub(/[^A-Za-z0-9\-]+/, "-")[0, 24]
    [ prefix.presence, digest[0, 24] ].compact.join("-")
  end

  def metadata_path(key)
    CACHE_DIR.join("#{key}.json")
  end

  def pdf_path(key)
    CACHE_DIR.join("#{key}.pdf")
  end

  def read_entry(key)
    meta_path = metadata_path(key)
    return unless File.exist?(meta_path) && File.exist?(pdf_path(key))

    data = JSON.parse(File.read(meta_path), symbolize_names: true)
    {
      fingerprint: data[:fingerprint],
      expires_at: time_from_store(data[:expires_at]),
      size: data[:size].to_i,
      last_accessed_at: time_from_store(data[:last_accessed_at]) || Time.current,
      path: pdf_path(key).to_s
    }
  rescue JSON::ParserError
    remove_entry(key)
    nil
  end

  def time_from_store(value)
    return nil if value.blank?
    Time.at(value.to_f)
  end

  def expired?(entry)
    entry[:expires_at] && entry[:expires_at] <= Time.current
  end

  def persist_entry(key, fingerprint, source_path, ttl)
    dest_path = pdf_path(key)
    FileUtils.mkdir_p(CACHE_DIR)
    FileUtils.mv(source_path, dest_path, force: true) unless File.identical?(source_path, dest_path)

    now = Time.current
    data = {
      fingerprint: fingerprint,
      size: File.size?(dest_path).to_i,
      expires_at: ttl ? (now + ttl).to_f : nil,
      last_accessed_at: now.to_f
    }

    File.write(metadata_path(key), JSON.generate(data))
    data.merge(path: dest_path.to_s)
  rescue Errno::ENOENT
    remove_entry(key)
    nil
  end

  def touch_entry(key, entry)
    meta_path = metadata_path(key)
    return unless File.exist?(meta_path)

    entry[:last_accessed_at] = Time.current
    data = {
      fingerprint: entry[:fingerprint],
      size: entry[:size],
      expires_at: entry[:expires_at]&.to_f,
      last_accessed_at: entry[:last_accessed_at].to_f
    }
    File.write(meta_path, JSON.generate(data))
  end

  def enforce_limits!
    entries = cache_entries.sort_by { |e| e[:last_accessed_at] || Time.at(0) }

    while entries.size > MAX_ENTRIES
      victim = entries.shift
      remove_entry(victim[:key]) if victim
    end

    total_bytes = entries.sum { |entry| entry[:size].to_i }
    while total_bytes > MAX_BYTES && entries.any?
      victim = entries.shift
      remove_entry(victim[:key])
      total_bytes -= victim[:size].to_i
    end
  end

  def cache_entries
    Dir.glob(CACHE_DIR.join("*.json")).filter_map do |meta_file|
      key = File.basename(meta_file, ".json")
      entry = read_entry(key)
      next unless entry

      entry.merge(key: key)
    end
  end

  def cleanup_expired!
    cache_entries.each do |entry|
      remove_entry(entry[:key]) if expired?(entry)
    end
  end

  def remove_entry(key)
    FileUtils.rm_f(metadata_path(key))
    FileUtils.rm_f(pdf_path(key))
  end
end
