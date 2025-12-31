# frozen_string_literal: true

class TableComponent < ViewComponent::Base
  def initialize(headers:, right_align: [])
    @headers = Array(headers)
    @right_align = Array(right_align).map(&:to_i)
  end

  private

  attr_reader :headers, :right_align

  def header_cell_classes(index)
    right_align.include?(index) ? "u-text-right" : ""
  end
end
