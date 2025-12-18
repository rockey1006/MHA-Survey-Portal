# PORO representing a student's aggregate responses for a survey. Provides
# convenience query methods used by dashboards and exports.
class SurveyResponse
  include ActiveModel::Model

  attr_reader :student, :survey

  class << self
    # Builds a response wrapper for the provided student and survey.
    #
    # @param student [Student]
    # @param survey [Survey]
    # @return [SurveyResponse]
    def build(student:, survey:)
      new(student: student, survey: survey)
    end

    # Rehydrates a response from a composite param ("studentId-surveyId").
    #
    # @param raw_id [String]
    # @return [SurveyResponse]
    # @raise [ActiveRecord::RecordNotFound]
    def find_from_param(raw_id)
      student_id, survey_id = raw_id.to_s.split("-", 2)
      raise ActiveRecord::RecordNotFound if student_id.blank? || survey_id.blank?

      student = Student.find(student_id)
      survey = Survey.find(survey_id)
      build(student: student, survey: survey)
    end

    # Looks up a response via a signed download token.
    #
    # @param token [String]
    # @return [SurveyResponse, nil]
    def find_by_signed_download_token(token)
      raw_id = verifier.verify(token)
      find_from_param(raw_id)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      nil
    end

    private

    def verifier
      Rails.application.message_verifier("survey-response")
    end
  end

  def initialize(student:, survey:)
    @student = student
    @survey = survey
  end

  # @return [String] composite identifier combining student and survey
  def id
    "#{student.student_id}-#{survey.id}"
  end

  # @return [String] id used in routing helpers
  def to_param
    id
  end

  # @return [Advisor, nil] advisor linked to the student
  def advisor
    student.advisor
  end

  # @return [Integer, nil] advisor primary key
  def advisor_id
    advisor&.advisor_id
  end

  # @return [Integer] student's primary key
  def student_id
    student.student_id
  end

  # @return [Integer] survey primary key
  def survey_id
    survey.id
  end

  # @return [Symbol] :not_started, :in_progress, or :submitted
  def status
    if total_required_questions.positive?
      return :not_started if answered_required_count.zero?
      return :submitted if answered_required_count == total_required_questions
      return :in_progress
    end

    return :not_started if answered_total_count.zero?
    answered_total_count == total_questions ? :submitted : :in_progress
  end

  # @return [Time, nil] most recent update across responses
  def completion_date
    @completion_date ||= question_responses.maximum(:updated_at)
  end

  # @return [Integer] number of answered questions (required + optional)
  def answered_count
    answered_total_count
  end

  # @return [Integer] number of answered required questions
  def answered_required_count
    @answered_required_count ||= required_questions.count do |question|
      present_answer?(answers[question.id])
    end
  end

  # @return [Integer] answered optional question count
  def answered_optional_count
    [ answered_total_count - answered_required_count, 0 ].max
  end

  # @return [Integer] number of answered questions (required + optional)
  def answered_total_count
    @answered_total_count ||= progress_questions.count do |question|
      present_answer?(answers[question.id])
    end
  end

  # @return [Integer] total questions in the survey (required + optional)
  def total_questions
    @total_questions ||= progress_questions.size
  end

  # @return [Integer] total required questions in the survey
  def total_required_questions
    @total_required_questions ||= required_questions.count
  end

  # @return [Integer] total optional questions in the survey
  def total_optional_questions
    @total_optional_questions ||= [ total_questions - total_required_questions, 0 ].max
  end

  # @return [Hash] precomputed counts for display
  def progress_summary
    @progress_summary ||= begin
      {
        answered_total: answered_total_count,
        total_questions: total_questions,
        answered_required: answered_required_count,
        total_required: total_required_questions,
        answered_optional: answered_optional_count,
        total_optional: total_optional_questions
      }
    end
  end

  # @return [Array<Question>] questions that are considered required
  def required_questions
    @required_questions ||= progress_questions.select { |question| required_for_completion?(question) }
  end

  # @return [String] signed token for secure downloads
  def signed_download_token
    self.class.send(:verifier).generate(id)
  end

  # @return [ActiveRecord::Relation<StudentQuestion>] responses for survey questions
  def question_responses
    question_ids = survey.questions.select(:id)
    @question_responses ||= StudentQuestion
                              .where(student_id: student.student_id, question_id: question_ids)
                              .includes(question: :category)
  end

  # @return [Hash{Integer => Object}] answers keyed by question id
  def answers
    @answers ||= question_responses.index_by(&:question_id).transform_values(&:answer)
  end

  # @return [Hash{Integer => Array<StudentQuestion>}] evidence responses grouped by category
  def evidence_history_by_category
    @evidence_history_by_category ||= begin
      grouped = Hash.new { |hash, key| hash[key] = [] }

      question_responses.each do |response|
        question = response.question
        category = question&.category
        next unless question&.question_type_evidence? && category

        grouped[category.id] << response
      end

      grouped.each_value do |responses|
        responses.sort_by! { |record| record.updated_at || record.created_at || Time.at(0) }
        responses.reverse!
      end

      grouped
    end
  end

  private

  # Only count parent questions in progress statistics so sub-questions don't
  # inflate completion percentages or required counts.
  #
  # @return [Array<Question>]
  def progress_questions
    @progress_questions ||= begin
      relation = survey.questions
      relation = relation.parent_questions if relation.respond_to?(:parent_questions)
      relation.to_a
    end
  end

  # Mirrors the controllers' required-question logic used for validation and dashboards.
  #
  # @param question [Question]
  # @return [Boolean]
  def required_for_completion?(question)
    return true if question.required?
    return false unless question.choice_question?

    option_values = question.question_type_dropdown? ? question.answer_option_values : question.answer_options_list
    options = option_values.map(&:strip).map(&:downcase)
    is_flexibility_scale = (options == %w[1 2 3 4 5]) &&
                           question.question_text.to_s.downcase.include?("flexible")
    !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
  end

  # Determines whether a stored answer should count as present for statistics.
  #
  # @param value [Object]
  # @return [Boolean]
  def present_answer?(value)
    case value
    when String
      value.strip.present?
    when Array
      value.any?(&:present?)
    else
      value.present?
    end
  end
end
