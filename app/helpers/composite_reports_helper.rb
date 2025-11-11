# frozen_string_literal: true

module CompositeReportsHelper
  DEFAULT_TRUNCATION_LIMIT = 5000
  TRUNCATION_SUFFIX = "... (truncated for PDF, view full response in the app)"

  # Truncates long text responses to keep PDF generation manageable on low-memory dynos.
  #
  # @param value [Object] raw answer/comment value
  # @param limit [Integer] maximum number of characters to retain
  # @return [Array(String, Boolean)] truncated string and flag indicating truncation
  def truncate_for_composite_pdf(value, limit: DEFAULT_TRUNCATION_LIMIT)
    text = value.to_s
    return [ text, false ] if text.blank? || text.length <= limit

    truncated = text[0, limit]
    [ truncated + TRUNCATION_SUFFIX, true ]
  end
end
