# frozen_string_literal: true

# Central rule registry and aggregation helpers for course competency math.
module CourseCompetencyRule
  DEFAULT_RULE = "max"

  LABELS = {
    "max" => "Max",
    "min" => "Min",
    "avg" => "Avg",
    "ceil_avg" => "Ceil(avg)",
    "floor_avg" => "Floor(avg)"
  }.freeze

  module_function

  def normalize(value)
    key = value.to_s.strip
    return DEFAULT_RULE if key.blank?

    LABELS.key?(key) ? key : DEFAULT_RULE
  end

  def label_for(value)
    LABELS.fetch(normalize(value))
  end

  def options
    LABELS.map { |key, label| { key: key, label: label } }
  end

  def aggregate(values, rule_key: DEFAULT_RULE)
    numeric_values = Array(values).compact.map(&:to_f)
    return nil if numeric_values.empty?

    case normalize(rule_key)
    when "max"
      numeric_values.max
    when "min"
      numeric_values.min
    when "avg"
      numeric_values.sum / numeric_values.length
    when "ceil_avg"
      (numeric_values.sum / numeric_values.length).ceil
    when "floor_avg"
      (numeric_values.sum / numeric_values.length).floor
    else
      numeric_values.max
    end
  end
end
