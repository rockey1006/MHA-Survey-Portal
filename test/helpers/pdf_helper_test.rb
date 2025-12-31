require "test_helper"

class PdfHelperTest < ActionView::TestCase
  include PdfHelper

  test "pdf_image_data_uri returns data uri for existing asset" do
    uri = pdf_image_data_uri("tamu-logo.png")
    assert_includes uri, "data:image/"
    assert_includes uri, ";base64,"
  end

  test "pdf_image_data_uri falls back to asset_path when missing" do
    value = pdf_image_data_uri("does-not-exist-#{SecureRandom.hex(4)}.png")
    assert value.start_with?("/"), "Expected a relative asset path, got: #{value.inspect}"
    refute_includes value, "data:", "Expected fallback to path, not data uri"
  end

  test "pdf_image_data_uri rescues asset pipeline lookup errors" do
    asset_name = "does-not-exist-#{SecureRandom.hex(4)}.png"

    fake_load_path = Class.new do
      def find(_name)
        raise StandardError, "boom"
      end
    end.new

    fake_assets = Struct.new(:load_path).new(fake_load_path)

    Rails.application.stub(:assets, fake_assets) do
      value = pdf_image_data_uri(asset_name)
      assert value.start_with?("/"), "Expected fallback asset path, got: #{value.inspect}"
      refute_includes value, "data:", "Expected fallback to path, not data uri"
    end
  end
end
