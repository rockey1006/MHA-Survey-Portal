require "test_helper"

class ReconcileSurveyAssignmentsJobTest < ActiveJob::TestCase
  test "perform is a no-op when survey missing" do
    calls = []
    SurveyAssignments::AutoAssigner.stub(:call, ->(**_) { calls << :called }) do
      ReconcileSurveyAssignmentsJob.perform_now(survey_id: 9_999_999)
    end

    assert_equal [], calls
  end

  test "perform enqueues auto assigner for students on survey tracks" do
    survey = surveys(:fall_2025)
    student = students(:student) # Residential

    calls = []
    SurveyAssignments::AutoAssigner.stub(:call, ->(student:) { calls << student.student_id }) do
      ReconcileSurveyAssignmentsJob.perform_now(survey_id: survey.id)
    end

    assert_includes calls, student.student_id
  end

  test "perform is a no-op when survey has no tracks" do
    semester = program_semesters(:fall_2025)
    survey = Survey.new(
      title: "No Tracks #{SecureRandom.hex(4)}",
      program_semester: semester,
      description: "",
      is_active: false
    )
    category = survey.categories.build(name: "Cat", description: "")
    category.questions.build(question_text: "Q", question_order: 0, question_type: "short_answer", is_required: false)
    survey.save!

    calls = []
    SurveyAssignments::AutoAssigner.stub(:call, ->(**_) { calls << :called }) do
      ReconcileSurveyAssignmentsJob.perform_now(survey_id: survey.id)
    end

    assert_equal [], calls
  end
end
