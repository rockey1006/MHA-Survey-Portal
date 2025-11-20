require "test_helper"
require "securerandom"

module Reports
  class DataAggregatorAdvisorScoresTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin)
      @student = students(:student)
      @advisor = advisors(:advisor)

      @competency_name = Reports::DataAggregator::COMPETENCY_TITLES.first
      @domain_name = Reports::DataAggregator::REPORT_DOMAINS.first

      @student_question, @advisor_question = create_competency_questions(@competency_name, @domain_name)
      @category = @student_question.category
      @survey = @category.survey
    end

    test "competency detail includes advisor averages" do
      create_student_response(score: "4.0")
      create_advisor_feedback(score: 5.0)

      aggregator = Reports::DataAggregator.new(user: @admin, params: {})
      item = aggregator.competency_detail[:items].find { |entry| entry[:name] == @competency_name }

      assert item, "Expected competency detail to include #{@competency_name}"
      assert_in_delta 4.0, item[:student_average], 0.001
      assert_in_delta 5.0, item[:advisor_average], 0.001
    end

    test "domain summary reflects advisor averages" do
      create_student_response(score: "3.5")
      create_advisor_feedback(score: 4.5)

      aggregator = Reports::DataAggregator.new(user: @admin, params: {})
      domain_entry = aggregator.competency_summary.find { |entry| entry[:name] == @domain_name }

      assert domain_entry, "Expected competency summary to include #{@domain_name}"
      assert_in_delta 3.5, domain_entry[:student_average], 0.001
      assert_in_delta 4.5, domain_entry[:advisor_average], 0.001
    end

    private

    def create_competency_questions(competency_name, domain_name)
      survey = Survey.create!(
        title: "Advisor Avg Survey #{SecureRandom.hex(4)}",
        semester: "Fall 2025",
        categories_attributes: [
          {
            name: domain_name,
            description: "Test domain",
            questions_attributes: [
              {
                question_text: competency_name,
                question_order: 1,
                question_type: "short_answer",
                is_required: true,
                has_evidence_field: false
              },
              {
                question_text: "#{competency_name} Reflection",
                question_order: 2,
                question_type: "short_answer",
                is_required: true,
                has_evidence_field: false
              }
            ]
          }
        ]
      )

      category = survey.categories.first
      questions = category.questions.order(:question_order)
      [ questions.first, questions.second ]
    end

    def create_student_response(score:)
      StudentQuestion.create!(
        student_id: @student.student_id,
        question: @student_question,
        response_value: score,
        advisor_id: nil
      )
    end

    def create_advisor_feedback(score:)
      Feedback.create!(
        student_id: @student.student_id,
        advisor_id: @advisor.advisor_id,
        question: @advisor_question,
        category: @category,
        survey: @survey,
        average_score: score
      )
    end
  end
end
