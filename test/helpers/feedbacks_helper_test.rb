require "test_helper"

class FeedbacksHelperTest < ActionView::TestCase
  include FeedbacksHelper

  test "normalize_proficiency_value normalizes numeric-like inputs" do
    assert_equal "3", normalize_proficiency_value(3)
    assert_equal "3", normalize_proficiency_value(3.0)
    assert_equal "4", normalize_proficiency_value("4")
    assert_nil normalize_proficiency_value(nil)
    assert_nil normalize_proficiency_value("not-a-number")
    assert_nil normalize_proficiency_value(0)
    assert_nil normalize_proficiency_value(6)
  end

  test "advisor_proficiency_option_pairs_for returns defaults when question options are unusable" do
    question = Struct.new(:answer_option_pairs).new([ [ "Beginner (1)", "Beginner (1)" ] ])
    pairs = advisor_proficiency_option_pairs_for(question)

    assert_equal 5, pairs.size
    assert_equal %w[1 2 3 4 5].sort, pairs.map { |(_l, v)| v }.sort
  end

  test "advisor_proficiency_option_pairs_for uses numeric options and removes 0" do
    pairs_input = [
      [ "Not able to assess", "0" ],
      [ "Beginner", "1" ],
      [ "Emerging", "2" ],
      [ "Capable", "3" ],
      [ "Experienced", "4" ],
      [ "Mastery", "5" ]
    ]
    question = Struct.new(:answer_option_pairs).new(pairs_input)

    pairs = advisor_proficiency_option_pairs_for(question)
    refute_includes pairs.map { |(_l, v)| v }, "0"
    assert_equal %w[1 2 3 4 5], pairs.map { |(_l, v)| v }
  end

  test "proficiency_label_for maps 0 to not assessable and nil to dash" do
    assert_equal "—", proficiency_label_for(nil)
    assert_equal NOT_ASSESSABLE_LABEL, proficiency_label_for(0)
    assert_equal NOT_ASSESSABLE_LABEL, proficiency_label_for("0")
  end

  test "proficiency_label_for prefers question labels when available" do
    pairs_input = [ [ "Beginner (1)", "1" ], [ "Emerging (2)", "2" ], [ "Capable (3)", "3" ], [ "Experienced (4)", "4" ], [ "Mastery (5)", "5" ] ]
    question = Struct.new(:answer_option_pairs).new(pairs_input)

    assert_equal "Capable (3)", proficiency_label_for("3", question)
  end
end
