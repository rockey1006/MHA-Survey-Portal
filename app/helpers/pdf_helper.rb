# frozen_string_literal: true

require "base64"

module PdfHelper
  def pdf_image_data_uri(asset_name)
    asset_name = asset_name.to_s
    safe_asset_name = File.basename(asset_name)
    return asset_path(safe_asset_name) if safe_asset_name.blank?

    candidates = [
      Rails.root.join("app", "assets", "images", safe_asset_name),
      Rails.root.join("public", "assets", safe_asset_name)
    ]

    path = candidates.find { |candidate| File.exist?(candidate) }

    if path.nil? && Rails.application.respond_to?(:assets) && Rails.application.assets.respond_to?(:load_path)
      begin
        found = Rails.application.assets.load_path.find(safe_asset_name)
        path = found if found && File.exist?(found)
      rescue StandardError
        path = nil
      end
    end

    return asset_path(safe_asset_name) if path.nil?

    mime_type = Rack::Mime.mime_type(File.extname(path.to_s), "image/png")
    encoded = Base64.strict_encode64(File.binread(path))
    "data:#{mime_type};base64,#{encoded}"
  end
end
