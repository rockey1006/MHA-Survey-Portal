# frozen_string_literal: true

require "test_helper"
require "securerandom"

module Reports
  class DataAggregatorTargetPercentTimelineTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin)
      @student = students(:student)
      @other_student = students(:other_student)
    end

    test "benchmark timeline includes target percent fields" do
      question = create_numeric_question("Timeline Metric Question")
      question.update!(program_target_level: 4)
      create_assignment(student: @student, survey: question.category.survey)
      create_assignment(student: @other_student, survey: question.category.survey)

      StudentQuestion.create!(
        student_id: @student.student_id,
        question: question,
        response_value: "4.0",
        updated_at: Time.current
      )

      StudentQuestion.create!(
        student_id: @other_student.student_id,
        question: question,
        response_value: "3.0",
        updated_at: Time.current
      )

      Feedback.create!(
        student_id: @student.student_id,
        advisor_id: @student.advisor&.advisor_id,
        survey: question.category.survey,
        category: question.category,
        question: question,
        average_score: 4.0,
        comments: "Ok",
        updated_at: Time.current
      )

      Feedback.create!(
        student_id: @other_student.student_id,
        advisor_id: @other_student.advisor&.advisor_id,
        survey: question.category.survey,
        category: question.category,
        question: question,
        average_score: 3.0,
        comments: "Ok",
        updated_at: Time.current
      )

      aggregator = Reports::DataAggregator.new(user: @admin, params: { survey_id: question.category.survey.id })
      timeline = Array(aggregator.benchmark[:timeline])

      assert timeline.any?, "Expected timeline entries to be present"

      point = timeline.last
      assert point.key?(:student_target_percent)
      assert point.key?(:advisor_target_percent)

      assert_in_delta 50.0, point[:student_target_percent], 0.001
      assert_in_delta 50.0, point[:advisor_target_percent], 0.001
    end

    private

    def create_assignment(student:, survey:)
      SurveyAssignment.create!(
        survey: survey,
        student: student,
        advisor_id: student.advisor&.advisor_id,
        assigned_at: Time.current - 1.day,
        completed_at: Time.current
      )
    end

    def create_numeric_question(question_text)
      survey = Survey.create!(
        title: "Timeline Test Survey #{SecureRandom.hex(4)}",
        semester: "Fall 2025",
        categories_attributes: [
          {
            name: Reports::DataAggregator::REPORT_DOMAINS.first,
            description: "Test domain",
            questions_attributes: [
              {
                question_text: question_text,
                question_order: 1,
                question_type: "short_answer",
                is_required: true,
                has_evidence_field: false
              }
            ]
          }
        ]
      )

      survey.questions.first
    end
  end
end
