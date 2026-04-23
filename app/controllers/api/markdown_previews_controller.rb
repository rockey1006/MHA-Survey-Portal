# frozen_string_literal: true

module Api
  class MarkdownPreviewsController < ApplicationController
    def create
      render json: {
        html: helpers.render_markdown(
          params[:text].to_s,
          wrapper_class: sanitized_wrapper_class,
          min_heading_level: sanitized_min_heading_level
        ).to_s
      }
    end

    private

    def sanitized_wrapper_class
      raw = params[:wrapper_class].to_s.strip
      return nil if raw.blank?
      return nil unless raw.match?(/\A[a-zA-Z0-9_\-\s]+\z/)

      raw
    end

    def sanitized_min_heading_level
      level = params[:min_heading_level].to_i
      return 1 unless level.between?(1, 6)

      level
    end
  end
end
