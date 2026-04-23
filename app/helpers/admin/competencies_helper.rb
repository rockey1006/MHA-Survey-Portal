# frozen_string_literal: true

module Admin::CompetenciesHelper
  def competency_matrix_rating(value)
    return "—" if value.nil?

    number_with_precision(value, precision: 1, strip_insignificant_zeros: true)
  end

  def competency_matrix_source_label(source)
    case source.to_sym
    when :self
      "Self"
    when :advisor
      "Advisor"
    when :course
      "Course"
    else
      source.to_s.humanize
    end
  end

  def competency_matrix_source_row_class(source)
    base = "c-competency-scorecard__row"

    case source.to_sym
    when :self
      "#{base} c-competency-scorecard__row--self"
    when :advisor
      "#{base} c-competency-scorecard__row--advisor"
    when :course
      "#{base} c-competency-scorecard__row--course"
    else
      base
    end
  end
end
