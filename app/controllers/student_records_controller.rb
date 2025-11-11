# Provides rollup views of survey completion status across students for staff
# members (advisors and admins).
class StudentRecordsController < ApplicationController
  before_action :require_staff_access!

  # Displays student survey completion matrices grouped by semester/survey.
  #
  # @return [void]
  def index
    @students = load_students
    @student_records = build_student_records(@students)
  end

  private

  # Ensures only advisors and admins can access student records.
  #
  # @return [void]
  def require_staff_access!
    return if current_user&.role_admin? || current_user&.role_advisor?

    redirect_to dashboard_path, alert: "Advisor or admin access required."
  end

  # Loads students accessible to the current staff member.
  #
  # @return [ActiveRecord::Relation<Student>]
  def load_students
    has_admin_privileges = current_user&.role_admin? || current_user&.admin_profile.present?

    scope = if has_admin_privileges
      Student.all
    else
      current_advisor_profile&.advisees || Student.none
    end

    scope
      .left_joins(:user)
      .includes(:user, advisor: :user)
      .order(Arel.sql("LOWER(users.name) ASC"))
  end

  # Builds a nested data structure summarizing survey completion for each
  # student.
  #
  # @param students [Enumerable<Student>]
  # @return [Array<Hash>]
  def build_student_records(students)
    return [] if students.blank?

  student_ids = students.map(&:student_id)

    surveys = Survey.includes(:questions).order(created_at: :desc)
    return [] if surveys.blank?

    survey_ids = surveys.map(&:id)

  feedback_lookup = load_feedback_lookup(student_ids, survey_ids)

    required_ids_by_survey = surveys.index_with do |survey|
      survey.questions.select { |question| required_question?(question) }.map(&:id)
    end

    responses_matrix = Hash.new do |hash, student_id|
      hash[student_id] = Hash.new { |inner, survey_id| inner[survey_id] = [] }
    end

    StudentQuestion
      .joins(question: :category)
      .where(student_id: student_ids, categories: { survey_id: survey_ids })
      .select("student_questions.id, student_questions.student_id, categories.survey_id, student_questions.question_id, student_questions.updated_at")
      .find_each do |record|
        responses_matrix[record.student_id][record.survey_id] << {
          question_id: record.question_id,
          updated_at: record.updated_at
        }
      end

    grouped = surveys.group_by(&:semester)

    sorted_semesters = grouped.keys.sort_by { |sem| semester_sort_key(sem) }.reverse

    sorted_semesters.map do |semester|
      {
        semester: semester.presence || "Unscheduled",
        surveys: grouped[semester].map do |survey|
          required_ids = required_ids_by_survey[survey.id]

          {
            survey: survey,
            rows: students.map do |student|
              responses = responses_matrix[student.student_id][survey.id]
              answered_ids = responses.map { |entry| entry[:question_id] }.uniq
              completed = if required_ids.present?
                (required_ids - answered_ids).empty?
              else
                answered_ids.any?
              end

              survey_response = SurveyResponse.build(student: student, survey: survey)

              feedbacks_for_pair = Array(feedback_lookup.dig(student.student_id, survey.id))
              feedback_last_updated = feedbacks_for_pair.filter_map(&:updated_at).max

              {
                student: student,
                advisor: student.advisor,
                status: completed ? "Completed" : "Pending",
                completed_at: responses.map { |entry| entry[:updated_at] }.compact.max,
                survey: survey,
                survey_response: survey_response,
                download_token: survey_response.signed_download_token,
                feedbacks: feedbacks_for_pair,
                feedback_last_updated_at: feedback_last_updated
              }
            end
          }
        end
      }
    end.reject { |block| block[:surveys].blank? }
  end

  # Produces a sortable key for semester labels (e.g., "Fall 2024").
  #
  # @param semester [String, nil]
  # @return [Array<Integer>]
  def semester_sort_key(semester)
    return [ 0, 0 ] if semester.blank?

    term, year = semester.to_s.split
    year_value = year.to_i
    term_value = case term&.downcase
    when "spring" then 1
    when "summer" then 2
    when "fall" then 3
    else 0
    end

    [ year_value, term_value ]
  end

  # Determines whether a question counts toward completion metrics.
  #
  # @param question [Question, nil]
  # @return [Boolean]
  def required_question?(question)
    return false unless question

    return true if question.required?

    return false unless question.question_type_multiple_choice?

    options = question.answer_options_list.map(&:strip).map(&:downcase)
    !(options == %w[yes no] || options == %w[no yes])
  end

  # Preloads feedback entries for the provided student and survey ids.
  #
  # @param student_ids [Array<Integer>]
  # @param survey_ids [Array<Integer>]
  # @return [Hash{Integer=>Hash{Integer=>Array<Feedback>}}]
  def load_feedback_lookup(student_ids, survey_ids)
    return {} if student_ids.blank? || survey_ids.blank?

    Feedback
      .includes(:category, advisor: :user)
      .where(student_id: student_ids, survey_id: survey_ids)
      .each_with_object(Hash.new { |hash, sid| hash[sid] = {} }) do |feedback, memo|
        memo[feedback.student_id][feedback.survey_id] ||= []
        memo[feedback.student_id][feedback.survey_id] << feedback
      end
      .tap do |lookup|
        lookup.each_value do |survey_hash|
          survey_hash.each_value do |entries|
            entries.sort_by! do |feedback|
              [
                feedback.category&.name.to_s.downcase,
                feedback.category_id || 0,
                feedback.id || 0
              ]
            end
          end
        end
      end
  end
end
