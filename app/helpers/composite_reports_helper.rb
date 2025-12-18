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

  # Normalizes stored answer shapes so PDF views can consistently render values.
  #
  # The app stores some answers as structured hashes (e.g. evidence links, "Other" text).
  # This helper extracts a predictable set of parts for view rendering.
  #
  # @param raw_answer [Object]
  # @return [Hash] keys: :value, :text, :link, :rating
  def composite_answer_parts(raw_answer)
    parts = { value: nil, text: nil, link: nil, rating: nil }

    case raw_answer
    when Hash
      parts[:value] = raw_answer["answer"] || raw_answer[:answer] || raw_answer["value"] || raw_answer[:value]
      parts[:text] = raw_answer["text"] || raw_answer[:text]
      parts[:link] = raw_answer["link"] || raw_answer[:link]
      parts[:rating] = raw_answer["rating"] || raw_answer[:rating]

      # Prefer an explicit answer value, but fall back to link/text for older payloads.
      parts[:value] ||= parts[:link] || parts[:text]
    when Array
      values = raw_answer.compact.map(&:to_s)
      parts[:value] = values
      parts[:text] = values.join(", ")
    else
      parts[:value] = raw_answer
      parts[:text] = raw_answer
    end

    parts
  end

  # Returns the best display string for an answer, preferring structured text fields when present.
  #
  # @param raw_answer [Object]
  # @return [String]
  def composite_display_answer(raw_answer)
    parts = composite_answer_parts(raw_answer)
    parts[:text].presence || (parts[:value].is_a?(Array) ? parts[:value].join(", ") : parts[:value]).to_s
  end
end
