require "test_helper"

class CompositeReportCacheTest < ActiveSupport::TestCase
  setup do
    CompositeReportCache.reset!
  end

  test "fetch caches value when fingerprint matches" do
    value = CompositeReportCache.fetch("key", "fingerprint") { "pdf-data" }
    assert_equal "pdf-data", value

    new_value = CompositeReportCache.fetch("key", "fingerprint") { "new-data" }
    assert_equal "pdf-data", new_value
  end

  test "fetch regenerates when fingerprint changes" do
    CompositeReportCache.fetch("key", "fingerprint-a") { "value-a" }
    regenerated = CompositeReportCache.fetch("key", "fingerprint-b") { "value-b" }
    assert_equal "value-b", regenerated
  end

  test "entries expire after ttl" do
    CompositeReportCache.fetch("key", "fingerprint", ttl: 1.hour) { "value-a" }
    travel 2.hours do
      regenerated = CompositeReportCache.fetch("key", "fingerprint", ttl: 1.hour) { "value-b" }
      assert_equal "value-b", regenerated
    end
  end

  test "nil values are not cached" do
    CompositeReportCache.fetch("key", "fingerprint") { nil }
    fresh = CompositeReportCache.fetch("key", "fingerprint") { "value" }
    assert_equal "value", fresh
  end

  test "evicts least recently used entries" do
    max = CompositeReportCache::MAX_ENTRIES
    max.times do |idx|
      CompositeReportCache.fetch("key-#{idx}", "fingerprint") { "value-#{idx}" }
    end

    # Access first key to keep it fresh
    CompositeReportCache.fetch("key-0", "fingerprint") { "stale" }

    # Adding a new entry should evict one of the older untouched entries
    CompositeReportCache.fetch("key-new", "fingerprint") { "value-new" }

    regenerated = CompositeReportCache.fetch("key-1", "fingerprint") { "regenerated" }
    assert_equal "regenerated", regenerated
  end
end
