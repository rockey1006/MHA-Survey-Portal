# View helpers supporting feedback pages.
module FeedbacksHelper
     DEFAULT_PROFICIENCY_PAIRS = [
          [ "Mastery (5)", "5" ],
          [ "Experienced (4)", "4" ],
          [ "Capable (3)", "3" ],
          [ "Emerging (2)", "2" ],
          [ "Beginner (1)", "1" ],
          [ "Not able to assess (0)", "0" ]
     ].freeze
     NOT_ASSESSABLE_LABEL = "Not able to assess".freeze

     # Normalizes stored scores (Integer/Float/String) into a dropdown value string.
     # Ensures values like 3.0 map to "3" so selects and labels match option values.
     #
     # @param score [String, Integer, Float, nil]
     # @return [String, nil]
     def normalize_proficiency_value(score)
          return nil if score.nil?

          numeric = begin
               Float(score)
          rescue StandardError
               nil
          end
          return nil if numeric.nil?

          int_value = numeric.round
          return nil unless int_value.between?(0, 5)

          int_value.to_s
     end

     # Returns the dropdown options for advisor feedback proficiency.
     # Prefer the question's own dropdown labels/values (the same ones students see),
     # then append the advisor-only 0 option.
     #
     # @param question [Question]
     # @return [Array<Array(String, String)>]
     def advisor_proficiency_option_pairs_for(question)
          base = if question && question.respond_to?(:answer_option_pairs)
               question.answer_option_pairs
          else
               []
          end

          # Some survey configs store dropdown options as label-only arrays (e.g.,
          # ["Beginner (1)", "Emerging (2)", ...]). In that case, Question#answer_option_pairs
          # returns [label, label], which breaks Feedback numeric validation.
          value_strings = Array(base).map { |(_label, value)| value.to_s.strip }
          numeric_values = value_strings.select { |v| v.match?(/\A[1-5]\z/) }
          base = DEFAULT_PROFICIENCY_PAIRS if base.blank? || numeric_values.size < 5

           # Ensure the advisor score dropdown is always 0–5 (blank means not assessed).
           has_zero = base.any? { |(_label, value)| value.to_s == "0" }
           return base if has_zero

           insert_after_value = "1"
           insert_index = base.index { |(_label, value)| value.to_s == insert_after_value }
           if insert_index
                base.dup.insert(insert_index + 1, [ "#{NOT_ASSESSABLE_LABEL} (0)", "0" ])
           else
                base.dup << [ "#{NOT_ASSESSABLE_LABEL} (0)", "0" ]
           end
     end

     # Maps a stored score into a label for display.
     # When a question is provided, prefer that question's labels (same as students).
     #
     # @param score [String, Integer, Float, nil]
     # @param question [Question, nil]
     # @return [String]
     def proficiency_label_for(score, question = nil)
          return "—" if score.nil?

          numeric = begin
               Float(score)
          rescue StandardError
               nil
          end
          return NOT_ASSESSABLE_LABEL if numeric && numeric.round.zero?

          normalized = normalize_proficiency_value(score) || score.to_s.strip

          pairs = advisor_proficiency_option_pairs_for(question)
          label = pairs.find { |(_lbl, val)| val.to_s == normalized }&.first
          label || normalized
     end
end
