# frozen_string_literal: true

require "test_helper"
require "securerandom"

module Reports
  class DataAggregatorCompetencyTargetLevelsTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin)
      @student = students(:student)
      @advisor = advisors(:advisor)

      @competency_name = Reports::DataAggregator::COMPETENCY_TITLES.first
      @domain_name = Reports::DataAggregator::REPORT_DOMAINS.first

      @student_question, @reflection_question = create_competency_questions(@competency_name, @domain_name)
      @category = @student_question.category
      @survey = @category.survey

      @student.update!(program_year: 1) if @student.program_year.blank?
      ensure_completed_assignment(student: @student, survey: @survey)
    end

    test "dataset rows use competency target levels (including Reflection normalization)" do
      @student_question.update!(program_target_level: 1)
      @reflection_question.update!(program_target_level: 2)

      CompetencyTargetLevel.create!(
        program_semester_id: @survey.program_semester_id,
        track: @student.track_before_type_cast,
        program_year: @student.program_year,
        competency_title: @competency_name,
        target_level: 5
      )

      StudentQuestion.create!(
        student_id: @student.student_id,
        question: @student_question,
        response_value: "4.0",
        advisor_id: nil
      )

      StudentQuestion.create!(
        student_id: @student.student_id,
        question: @reflection_question,
        response_value: "4.0",
        advisor_id: nil
      )

      aggregator = Reports::DataAggregator.new(user: @admin, params: {})
      rows = aggregator.send(:dataset_rows)

      base_row = rows.find { |row| row[:question_text] == @competency_name }
      refute_nil base_row
      assert_equal 5, base_row[:program_target_level]

      reflection_row = rows.find { |row| row[:question_text] == "#{@competency_name} Reflection" }
      refute_nil reflection_row
      assert_equal 5, reflection_row[:program_target_level]
    end

    test "dataset rows fall back to any available program_year when student program_year is missing" do
      @student.update!(program_year: nil)
      @student_question.update!(program_target_level: 1)

      CompetencyTargetLevel.create!(
        program_semester_id: @survey.program_semester_id,
        track: @student.track_before_type_cast,
        program_year: 1,
        competency_title: @competency_name,
        target_level: 4
      )

      StudentQuestion.create!(
        student_id: @student.student_id,
        question: @student_question,
        response_value: "4.0",
        advisor_id: nil
      )

      aggregator = Reports::DataAggregator.new(user: @admin, params: {})
      rows = aggregator.send(:dataset_rows)

      base_row = rows.find { |row| row[:question_text] == @competency_name }
      refute_nil base_row
      assert_equal 4, base_row[:program_target_level]
    end

    private

    def create_competency_questions(competency_name, domain_name)
      survey = Survey.create!(
        title: "Target Level Report Survey #{SecureRandom.hex(4)}",
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

    def ensure_completed_assignment(student:, survey:)
      assignment = SurveyAssignment.find_or_initialize_by(
        survey: survey,
        student: student
      )
      assignment.advisor_id ||= student.advisor&.advisor_id
      assignment.assigned_at ||= Time.current - 2.weeks
      assignment.save!
      assignment.update!(completed_at: assignment.completed_at || Time.current - 1.week)
    end
  end
end
