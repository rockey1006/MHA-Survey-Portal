# frozen_string_literal: true

class ToolbarSearchComponent < ViewComponent::Base
  def initialize(url:, query:, param_name: :q, placeholder: "Search...", hidden_params: {})
    @url = url
    @query = query
    @param_name = param_name
    @placeholder = placeholder
    @hidden_params = hidden_params
  end

  private

  attr_reader :url, :query, :param_name, :placeholder, :hidden_params
end
