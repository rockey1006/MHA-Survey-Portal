class SurveyResponse
  include ActiveModel::Model

  attr_reader :student, :survey

  class << self
    def build(student:, survey:)
      new(student: student, survey: survey)
    end

    def find_from_param(raw_id)
      student_id, survey_id = raw_id.to_s.split("-", 2)
      raise ActiveRecord::RecordNotFound if student_id.blank? || survey_id.blank?

      student = Student.find(student_id)
      survey = Survey.find(survey_id)
      build(student: student, survey: survey)
    end

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

  def id
    "#{student.student_id}-#{survey.id}"
  end

  def to_param
    id
  end

  def advisor
    student.advisor
  end

  def advisor_id
    advisor&.advisor_id
  end

  def student_id
    student.student_id
  end

  def survey_id
    survey.id
  end

  def status
    return :not_started if answered_count.zero?
    answered_count == total_questions ? :submitted : :in_progress
  end

  def completion_date
    @completion_date ||= question_responses.maximum(:updated_at)
  end

  def answered_count
    @answered_count ||= question_responses.select { |record| present_answer?(record.answer) }.count
  end

  def total_questions
    @total_questions ||= survey.questions.count
  end

  def signed_download_token
    self.class.send(:verifier).generate(id)
  end

  def question_responses
    question_ids = survey.questions.select(:id)
    @question_responses ||= StudentQuestion
                              .where(student_id: student.student_id, question_id: question_ids)
                              .includes(question: :category)
  end

  def answers
    @answers ||= question_responses.index_by(&:question_id).transform_values(&:answer)
  end

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
