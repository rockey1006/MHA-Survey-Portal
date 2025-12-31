# frozen_string_literal: true

class ToolbarSearchComponent < ViewComponent::Base
  def initialize(url:, query:, param_name: :q, placeholder: "Search...")
    @url = url
    @query = query
    @param_name = param_name
    @placeholder = placeholder
  end

  private

  attr_reader :url, :query, :param_name, :placeholder
end
