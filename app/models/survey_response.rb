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
    return :not_started if answered_count.zero?
    answered_count == total_questions ? :submitted : :in_progress
  end

  # @return [Time, nil] most recent update across responses
  def completion_date
    @completion_date ||= question_responses.maximum(:updated_at)
  end

  # @return [Integer] number of answered questions
  def answered_count
    @answered_count ||= question_responses.select { |record| present_answer?(record.answer) }.count
  end

  # @return [Integer] total questions in the survey
  def total_questions
    @total_questions ||= survey.questions.count
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
