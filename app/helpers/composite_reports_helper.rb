# frozen_string_literal: true

module CompositeReportsHelper
  DEFAULT_TRUNCATION_LIMIT = 5000
  TRUNCATION_SUFFIX = "... (truncated for PDF, view full response in the app)"

  DEFAULT_PROFICIENCY_OPTION_PAIRS = [
    [ "Mastery (5)", "5" ],
    [ "Experienced (4)", "4" ],
    [ "Capable (3)", "3" ],
    [ "Emerging (2)", "2" ],
    [ "Beginner (1)", "1" ],
    [ "Not able to assess (0)", "0" ]
  ].freeze

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

  # Returns [label, value] pairs for proficiency dropdowns used in the PDF.
  # Prefer the question's own dropdown options (student labels).
  def proficiency_option_pairs_for(question)
    base = if question && question.respond_to?(:answer_option_pairs)
      question.answer_option_pairs
    else
      []
    end

    base = DEFAULT_PROFICIENCY_OPTION_PAIRS if base.blank?
    has_zero = base.any? { |(_label, value)| value.to_s == "0" }
    return base if has_zero

    insert_after_value = "1"
    insert_index = base.index { |(_label, value)| value.to_s == insert_after_value }
    if insert_index
      base.dup.insert(insert_index + 1, ["Not able to assess (0)", "0"])
    else
      base.dup << ["Not able to assess (0)", "0"]
    end
  end

  # Normalizes stored feedback scores into a dropdown value string.
  def normalize_proficiency_value(score)
    return nil if score.nil?

    int_value = score.to_f.round
    return nil unless int_value.between?(0, 5)

    int_value.to_s
  end
end
