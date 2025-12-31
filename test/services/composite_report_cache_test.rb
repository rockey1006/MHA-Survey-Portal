require "test_helper"

class CompositeReportCacheTest < ActiveSupport::TestCase
  setup do
    CompositeReportCache.reset!
  end

  test "fetch caches file path when fingerprint matches" do
    result = CompositeReportCache.fetch("key", "fingerprint") { build_pdf("pdf-data") }
    assert_kind_of CompositeReportCache::Result, result
    assert File.exist?(result.path)
    assert_equal "pdf-data", File.binread(result.path)
    refute result.cached?

    cached = CompositeReportCache.fetch("key", "fingerprint") { build_pdf("new-data") }
    assert_equal "pdf-data", File.binread(cached.path)
    assert cached.cached?
  end

  test "fetch regenerates when fingerprint changes" do
    CompositeReportCache.fetch("key", "fingerprint-a") { build_pdf("value-a") }
    regenerated = CompositeReportCache.fetch("key", "fingerprint-b") { build_pdf("value-b") }
    assert_equal "value-b", File.binread(regenerated.path)
    refute regenerated.cached?
  end

  test "entries expire after ttl" do
    CompositeReportCache.fetch("key", "fingerprint", ttl: 1.hour) { build_pdf("value-a") }
    travel 2.hours do
      regenerated = CompositeReportCache.fetch("key", "fingerprint", ttl: 1.hour) { build_pdf("value-b") }
      assert_equal "value-b", File.binread(regenerated.path)
      refute regenerated.cached?
    end
  end

  test "nil values are not cached" do
    CompositeReportCache.fetch("key", "fingerprint") { nil }
    fresh = CompositeReportCache.fetch("key", "fingerprint") { build_pdf("value") }
    assert_equal "value", File.binread(fresh.path)
  end

  test "evicts least recently used entries" do
    original_max = CompositeReportCache::MAX_ENTRIES
    CompositeReportCache.send(:remove_const, :MAX_ENTRIES)
    CompositeReportCache.const_set(:MAX_ENTRIES, 3)
    CompositeReportCache.reset!

    travel_to Time.zone.local(2025, 1, 1, 0, 0, 0) do
      CompositeReportCache.fetch("key-0", "fingerprint") { build_pdf("value-0") }
      travel 1.second
      CompositeReportCache.fetch("key-1", "fingerprint") { build_pdf("value-1") }
      travel 1.second
      CompositeReportCache.fetch("key-2", "fingerprint") { build_pdf("value-2") }
      travel 1.second

      CompositeReportCache.fetch("key-0", "fingerprint") { build_pdf("stale") }
      travel 1.second

      CompositeReportCache.fetch("key-new", "fingerprint") { build_pdf("value-new") }
      travel 1.second

      regenerated = CompositeReportCache.fetch("key-1", "fingerprint") { build_pdf("regenerated") }
      assert_equal "regenerated", File.binread(regenerated.path)
    end
  ensure
    CompositeReportCache.send(:remove_const, :MAX_ENTRIES)
    CompositeReportCache.const_set(:MAX_ENTRIES, original_max)
    CompositeReportCache.reset!
  end

  private

  def build_pdf(content)
    file = Tempfile.new([ "composite-cache", ".pdf" ])
    file.binmode
    file.write(content)
    file.flush
    file.close
    file
  end
end
