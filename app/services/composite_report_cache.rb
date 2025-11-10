# frozen_string_literal: true

# Simple in-memory cache with LRU eviction for composite assessment PDFs.
# Stores up to MAX_ENTRIES PDF payloads and expires them after ENTRY_TTL.
class CompositeReportCache
  MAX_ENTRIES = 50
  ENTRY_TTL = 12.hours

  Entry = Struct.new(:data, :fingerprint, :expires_at, :last_accessed, keyword_init: true) do
    def expired?(time)
      expires_at && expires_at <= time
    end

    def matches?(other_fingerprint)
      fingerprint == other_fingerprint
    end

    def valid_for?(other_fingerprint, time)
      matches?(other_fingerprint) && !expired?(time)
    end

    def touch(time)
      self.last_accessed = time
    end
  end

  class << self
    # Fetches a cached entry or stores the provided block result.
    #
    # @param key [String]
    # @param fingerprint [String]
    # @param ttl [ActiveSupport::Duration]
    # @yieldreturn [String, nil]
    # @return [String, nil]
    def fetch(key, fingerprint, ttl: ENTRY_TTL, &block)
      instance.fetch(key, fingerprint, ttl: ttl, &block)
    end

    # Clears the cache (used in tests).
    def reset!
      @instance = new
    end

    private

    def instance
      @instance ||= new
    end
  end

  def initialize
    @store = {}
    @mutex = Mutex.new
  end

  # Internal fetch implementation; see ::fetch.
  #
  # @param key [String]
  # @param fingerprint [String]
  # @param ttl [ActiveSupport::Duration]
  # @yieldreturn [String, nil]
  # @return [String, nil]
  def fetch(key, fingerprint, ttl: ENTRY_TTL)
    now = Time.current

    @mutex.synchronize do
      entry = @store[key]
      if entry&.valid_for?(fingerprint, now)
        entry.touch(now)
        return entry.data
      end

      if entry&.expired?(now)
        @store.delete(key)
      end
    end

    data = yield
    return data if data.nil?

    written_at = Time.current
    expires_at = ttl ? written_at + ttl : nil

    @mutex.synchronize do
      @store[key] = Entry.new(data: data, fingerprint: fingerprint, expires_at: expires_at, last_accessed: written_at)
      prune_locked(written_at)
    end

    data
  end

  private

  # Removes expired entries and prunes the store down to MAX_ENTRIES using LRU order.
  #
  # @param now [Time]
  # @return [void]
  def prune_locked(now)
    expired_keys = @store.select { |_, entry| entry.expired?(now) }.keys
    expired_keys.each { |k| @store.delete(k) }

    while @store.size > MAX_ENTRIES
      lru_key, _ = @store.min_by { |_, entry| entry.last_accessed || Time.at(0) }
      break unless lru_key
      @store.delete(lru_key)
    end
  end
end
