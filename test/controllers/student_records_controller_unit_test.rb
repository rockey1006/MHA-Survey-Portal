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

  test "load_employment_export_lookup extracts normalized employment fields" do
    controller = StudentRecordsController.new
    student = students(:student)
    survey = surveys(:fall_2025)

    employment = Category.create!(
      survey: survey,
      name: "Employment Information",
      description: "Employment details"
    )

    employed_question = employment.questions.create!(
      question_text: "Are you currently employed?",
      question_order: 1,
      question_type: "multiple_choice",
      is_required: true,
      answer_options: [ "Yes", "No" ].to_json
    )
    employer_question = employment.questions.create!(
      question_text: "If yes, where are you employed? (name and address)",
      question_order: 2,
      question_type: "short_answer",
      is_required: false
    )
    title_question = employment.questions.create!(
      question_text: "What is your title?",
      question_order: 3,
      question_type: "short_answer",
      is_required: false
    )
    hours_question = employment.questions.create!(
      question_text: "How many hours per week do you work on average?",
      question_order: 4,
      question_type: "short_answer",
      is_required: false
    )
    flexibility_question = employment.questions.create!(
      question_text: "How flexible are your work hours?",
      question_order: 5,
      question_type: "multiple_choice",
      is_required: false,
      answer_options: [
        [ "1 - No flexibility", "1" ],
        [ "5 - Very flexible", "5" ],
        { label: "Other", value: "0", requires_text: true }
      ].to_json
    )

    StudentQuestion.create!(student: student, question: employed_question, response_value: "Yes")
    StudentQuestion.create!(student: student, question: employer_question, response_value: "St. Joseph Health, Bryan, TX")
    StudentQuestion.create!(student: student, question: title_question, response_value: "Graduate Intern")
    StudentQuestion.create!(student: student, question: hours_question, response_value: "32")
    StudentQuestion.create!(
      student: student,
      question: flexibility_question,
      response_value: { answer: "0", text: "Hybrid with occasional weekends" }.to_json
    )

    lookup = controller.send(:load_employment_export_lookup, [ student.student_id ], [ survey.id ])
    row = lookup[[ student.student_id, survey.id ]]

    assert_equal "Yes", row[:currently_employed]
    assert_equal "St. Joseph Health, Bryan, TX", row[:employer]
    assert_equal "Graduate Intern", row[:job_title]
    assert_equal "32", row[:hours_per_week]
    assert_equal "Hybrid with occasional weekends", row[:work_schedule_flexibility]
  end

  test "build_student_records_workbook includes employment columns and values" do
    controller = StudentRecordsController.new
    student = students(:student)
    survey = surveys(:fall_2025)

    workbook = controller.send(
      :build_student_records_workbook,
      [
        {
          semester: "Fall 2025",
          surveys: [
            {
              survey: survey,
              rows: [
                {
                  student: student,
                  advisor: student.advisor,
                  status: "Completed",
                  completed_at: Time.zone.parse("2025-10-01 08:00"),
                  feedback_status_label: "Submitted",
                  feedback_status_timestamp: Time.zone.parse("2025-10-02 08:00"),
                  employment_data: {
                    currently_employed: "Yes",
                    employer: "St. Joseph Health, Bryan, TX",
                    job_title: "Graduate Intern",
                    hours_per_week: "32",
                    work_schedule_flexibility: "Hybrid"
                  }
                }
              ]
            }
          ]
        }
      ]
    )

    sheet = workbook.workbook.worksheets.first
    headers = sheet.rows[3].cells.map(&:value)
    values = sheet.rows[4].cells.map(&:value)

    assert_includes headers, "Employment Status"
    assert_includes headers, "Employer (Name and Address)"
    assert_includes headers, "Job Title"
    assert_includes headers, "Avg Hours/Week"
    assert_includes headers, "Work Schedule Flexibility"

    assert_includes values, "Yes"
    assert_includes values, "St. Joseph Health, Bryan, TX"
    assert_includes values, "Graduate Intern"
    assert_includes values, 32
    assert_includes values, "Hybrid"
  end
end
