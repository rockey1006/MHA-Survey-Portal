# frozen_string_literal: true

require "test_helper"
require "securerandom"

module Reports
  class DataAggregatorSummaryCardsTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin)
      @student = students(:student)
      @other_student = students(:other_student)
    end

    test "completion rate is zero when assignments missing" do
      SurveyAssignment.delete_all
      StudentQuestion.delete_all

      question = create_numeric_question("Completion Metric Question")
      StudentQuestion.create!(
        student_id: @student.student_id,
        question: question,
        response_value: "4.0"
      )

      aggregator = Reports::DataAggregator.new(user: @admin, params: {})
      completion_card = aggregator.benchmark[:cards].find { |card| card[:key] == "completion_rate" }

      refute_nil completion_card, "Expected completion card to be present"
      assert_in_delta 0.0, completion_card[:value], 0.01
      assert_equal aggregator.send(:scoped_student_ids).size, completion_card[:sample_size]
    end

    test "completion rate counts only completed assignments" do
      SurveyAssignment.delete_all
      StudentQuestion.delete_all

      question = create_numeric_question("Completion Metric Question")
      assignment = create_assignment(student: @student, survey: question.category.survey, completed: false)

      StudentQuestion.create!(
        student_id: @student.student_id,
        question: question,
        response_value: "4.0"
      )

      aggregator = Reports::DataAggregator.new(user: @admin, params: {})
      completion_card = aggregator.benchmark[:cards].find { |card| card[:key] == "completion_rate" }

      refute_nil completion_card, "Expected completion card to be present"
      assert_in_delta 0.0, completion_card[:value], 0.01
      assert_equal 1, completion_card[:sample_size]

      assignment.update!(completed_at: Time.current)

      refreshed = Reports::DataAggregator.new(user: @admin, params: {})
      completion_card_after = refreshed.benchmark[:cards].find { |card| card[:key] == "completion_rate" }

      refute_nil completion_card_after
      assert_in_delta 100.0, completion_card_after[:value], 0.01
      assert_equal 1, completion_card_after[:sample_size]
    end

    test "completion rate aggregates across multiple students" do
      SurveyAssignment.delete_all
      StudentQuestion.delete_all

      question = create_numeric_question("Completion Metric Question")

      create_assignment(student: @student, survey: question.category.survey, completed: true)
      create_assignment(student: @other_student, survey: question.category.survey, completed: false)

      [ @student, @other_student ].each do |student|
        StudentQuestion.create!(
          student_id: student.student_id,
          question: question,
          response_value: "4.0"
        )
      end

      aggregator = Reports::DataAggregator.new(user: @admin, params: {})
      completion_card = aggregator.benchmark[:cards].find { |card| card[:key] == "completion_rate" }

      refute_nil completion_card, "Expected completion card to be present"
      assert_in_delta 50.0, completion_card[:value], 0.01
      assert_equal 2, completion_card[:sample_size]

      SurveyAssignment.where(student_id: @other_student.student_id, survey_id: question.category.survey.id)
                      .update_all(completed_at: Time.current)

      refreshed = Reports::DataAggregator.new(user: @admin, params: {})
      completion_card_after = refreshed.benchmark[:cards].find { |card| card[:key] == "completion_rate" }

      assert_in_delta 100.0, completion_card_after[:value], 0.01
      assert_equal 2, completion_card_after[:sample_size]
    end

    test "competency goal metric counts students meeting threshold per competency" do
      SurveyAssignment.delete_all
      StudentQuestion.delete_all

      survey = create_empty_domain_survey
      create_assignment(student: @student, survey: survey, completed: true)
      create_assignment(student: @other_student, survey: survey, completed: true)
      categories = survey.categories.order(:id)

      Reports::DataAggregator::COMPETENCY_TITLES.each_with_index do |title, index|
        category = categories[index % categories.length]
        question = category.questions.create!(
          question_text: title,
          question_order: index + 1,
          question_type: "short_answer",
          is_required: true,
          has_evidence_field: false
        )

        StudentQuestion.create!(student_id: @student.student_id, question: question, response_value: "4.0")
        StudentQuestion.create!(
          student_id: @other_student.student_id,
          question: question,
          response_value: index.even? ? "4.1" : "3.0"
        )
      end

      aggregator = Reports::DataAggregator.new(user: @admin, params: {})
      goal_card = aggregator.benchmark[:cards].find { |card| card[:key] == "competency_goal_attainment" }

      refute_nil goal_card, "Expected competency goal card to be present"
      assert_operator goal_card[:value], :>, 0.0
      assert_equal 2, goal_card[:sample_size]
      assert_equal 1, goal_card.dig(:meta, :students_met_goal)
    end

    private

    def create_assignment(student:, survey:, completed: true)
      SurveyAssignment.create!(
        survey: survey,
        student: student,
        advisor_id: student.advisor&.advisor_id,
        assigned_at: Time.current - 1.week,
        completed_at: completed ? (Time.current - 1.day) : nil
      )
    end

    def create_numeric_question(question_text)
      survey = Survey.create!(
        title: "Completion Metric Survey #{SecureRandom.hex(4)}",
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

    def create_empty_domain_survey
      Survey.create!(
        title: "Competency Goal Survey #{SecureRandom.hex(4)}",
        semester: "Fall 2025",
        categories_attributes: Reports::DataAggregator::REPORT_DOMAINS.map.with_index do |name, index|
          {
            name: name,
            description: "Domain #{index}",
            questions_attributes: [
              {
                question_text: "Seed Question #{index}",
                question_order: 1,
                question_type: "short_answer",
                is_required: true,
                has_evidence_field: false
              }
            ]
          }
        end
      )
    end
  end
end
