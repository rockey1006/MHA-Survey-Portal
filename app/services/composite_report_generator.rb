# frozen_string_literal: true

require "digest"

# Builds the composite assessment PDF that merges student responses and advisor feedback.
class CompositeReportGenerator
  class MissingDependency < StandardError; end
  class GenerationError < StandardError; end

  CACHE_TTL = 12.hours

  def initialize(survey_response:)
    @survey_response = survey_response
  end

  # Renders (or retrieves) the PDF string for the survey response composite report.
  #
  # @return [String]
  def render
    ensure_dependency!
    fingerprint = cache_fingerprint

    CompositeReportCache.fetch(cache_key, fingerprint, ttl: CACHE_TTL) do
      html = render_html
      WickedPdf.new.pdf_from_string(html)
    end
  rescue MissingDependency
    raise
  rescue => e
    Rails.logger.error "[CompositeReportGenerator] generation failed for SurveyResponse=#{@survey_response.id}: #{e.class} - #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
    raise GenerationError, e.message
  end

  # Exposed for tests to verify cache invalidation logic applies expected inputs.
  #
  # @return [String]
  def cache_fingerprint
    responses = question_responses
    feedback_entries = feedback_records

    response_updated = responses.filter_map { |r| r.updated_at&.to_i }
    response_created = responses.filter_map { |r| r.created_at&.to_i }

    feedback_updated = feedback_entries.filter_map { |f| f.updated_at&.to_i }
    feedback_created = feedback_entries.filter_map { |f| f.created_at&.to_i }

    components = [
      @survey_response.student_id,
      student.updated_at&.to_i,
      student.user&.updated_at&.to_i,
      survey.id,
      survey.updated_at&.to_i,
      advisor&.advisor_id,
      advisor&.updated_at&.to_i,
      advisor&.user&.updated_at&.to_i,
      responses.size,
      response_updated.max,
      response_created.max,
      feedback_entries.size,
      feedback_updated.max,
      feedback_created.max,
      feedback_entries.map(&:id).max,
      @survey_response.status.to_s,
      @survey_response.completion_date&.to_i
    ]

    Digest::SHA256.hexdigest(components.map { |value| value.present? ? value : "nil" }.join("|"))
  end

  private

  def ensure_dependency!
    raise MissingDependency, "WickedPdf not loaded" unless defined?(WickedPdf)
  end

  def cache_key
    "composite-report:#{@survey_response.id}"
  end

  def render_html
    timestamp = Time.current
    ApplicationController.render(
      template: "composite_reports/show",
      layout: "pdf",
      assigns: view_assigns(timestamp),
      formats: [ :html ]
    )
  end

  def view_assigns(generated_at)
    {
      survey_response: @survey_response,
      student: student,
      advisor: advisor,
      survey: survey,
      categories: categories,
      question_responses: question_responses,
  responses_by_question: responses_by_question,
      answers_by_question: answers_by_question,
      feedbacks_by_category: feedbacks_by_category,
      feedback_summary: feedback_summary,
      evidence_history_by_category: evidence_history_by_category,
      generated_at: generated_at,
      answered_count: answered_count,
      total_questions: total_questions
    }
  end

  def student
    @student ||= @survey_response.student
  end

  def advisor
    @advisor ||= @survey_response.advisor
  end

  def survey
    @survey ||= @survey_response.survey
  end

  def categories
    @categories ||= survey.categories.includes(:questions).order(:id).to_a
  end

  def question_responses
    @question_responses ||= @survey_response.question_responses.to_a
  end

  def answers_by_question
    @answers_by_question ||= @survey_response.answers
  end

  def responses_by_question
    @responses_by_question ||= question_responses.index_by(&:question_id)
  end

  def feedback_scope
    base = Feedback.where(student_id: student.student_id, survey_id: survey.id).includes(:category, :advisor)
    if advisor&.advisor_id
      base.where(advisor_id: advisor.advisor_id)
    else
      base
    end
  end

  def feedback_records
    @feedback_records ||= feedback_scope.to_a
  end

  def feedbacks_by_category
    @feedbacks_by_category ||= feedback_records.group_by(&:category_id).transform_values do |entries|
      entries.sort_by { |entry| entry.updated_at || entry.created_at || Time.at(0) }.reverse
    end
  end

  def feedback_summary
    @feedback_summary ||= begin
      entries = feedback_records
      scores = entries.map(&:average_score).compact.map(&:to_f)
      {
        total_entries: entries.size,
        scored_entries: scores.size,
        average_score: scores.any? ? (scores.sum / scores.size).round(2) : nil,
        latest_feedback_at: entries.filter_map { |entry| entry.updated_at || entry.created_at }.max
      }
    end
  end

  def evidence_history_by_category
    @evidence_history_by_category ||= @survey_response.evidence_history_by_category
  end

  def answered_count
    @answered_count ||= @survey_response.answered_count
  end

  def total_questions
    @total_questions ||= @survey_response.total_questions
  end
end
