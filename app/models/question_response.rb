class QuestionResponse < ApplicationRecord
  belongs_to :question, optional: true
  belongs_to :competency_response, optional: true

  # store answer as text; for checkbox/multi select we can store comma-separated or JSON
  # The app previously used `serialize :answer, JSON` here but some
  # environments/gems define a conflicting `serialize` method that
  # expects a different arity, causing a class-load ArgumentError.
  # Use explicit getter/setter to keep behavior consistent and avoid
  # loading-time conflicts.
  def answer
    raw = read_attribute(:answer)
    return nil if raw.nil?
    # If the stored value looks like JSON, parse it; otherwise return
    # the raw string (for backward compatibility).
    if raw.is_a?(String) && raw.strip.start_with?("{") || raw.strip.start_with?("[")
      begin
        JSON.parse(raw)
      rescue JSON::ParserError
        raw
      end
    else
      raw
    end
  end

  def answer=(val)
    if val.is_a?(String)
      write_attribute(:answer, val)
    else
      # store arrays/hashes as JSON string
      write_attribute(:answer, val.to_json)
    end
  end
end
