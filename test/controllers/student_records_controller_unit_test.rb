require "test_helper"

class StudentRecordsControllerUnitTest < ActiveSupport::TestCase
  test "required_question? applies yes/no and flexibility scale exceptions" do
    controller = StudentRecordsController.new

    required_question = Struct.new(:required?, :choice_question?, :answer_option_values, :question_text).new(true, false, [], "")
    assert_equal true, controller.send(:required_question?, required_question)

    yes_no = Struct.new(:required?, :choice_question?, :answer_option_values, :question_text).new(false, true, [ "Yes", "No" ], "")
    assert_equal false, controller.send(:required_question?, yes_no)

    flexibility = Struct.new(:required?, :choice_question?, :answer_option_values, :question_text).new(false, true, %w[1 2 3 4 5], "How flexible are you?")
    assert_equal false, controller.send(:required_question?, flexibility)

    other_choice = Struct.new(:required?, :choice_question?, :answer_option_values, :question_text).new(false, true, %w[A B C], "")
    assert_equal true, controller.send(:required_question?, other_choice)
  end

  test "semester_sort_key handles nil and known terms" do
    controller = StudentRecordsController.new

    assert_equal [ 0, 0 ], controller.send(:semester_sort_key, nil)
    assert_equal [ 2025, 3 ], controller.send(:semester_sort_key, "Fall 2025")
    assert_equal [ 2025, 1 ], controller.send(:semester_sort_key, "Spring 2025")
    assert_equal [ 2025, 2 ], controller.send(:semester_sort_key, "Summer 2025")
  end
end
