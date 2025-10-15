class StudentRecordsController < ApplicationController
  before_action :require_staff_access!

  def index
    @students = load_students
    @student_records = build_student_records(@students)
  end

  private

  def require_staff_access!
    return if current_user&.role_admin? || current_user&.role_advisor?

    redirect_to dashboard_path, alert: "Advisor or admin access required."
  end

  def load_students
    has_admin_privileges = current_user&.role_admin? || current_user&.admin_profile.present?

    scope = if has_admin_privileges
      Student.includes(:user, advisor: :user)
    else
      current_advisor_profile&.advisees&.includes(:user, advisor: :user) || Student.none
    end

    scope
      .left_joins(:user)
      .includes(:advisor, survey_responses: :survey)
      .order(Arel.sql("LOWER(users.name) ASC"))
  end

  def build_student_records(students)
    return [] if students.blank?

    student_ids = students.map(&:student_id)

    surveys = Survey
      .includes(survey_responses: [ :student, { advisor: :user } ])
      .order(created_at: :desc)

    grouped = surveys.group_by(&:semester)

    sorted_semesters = grouped.keys.sort_by { |sem| semester_sort_key(sem) }.reverse

    sorted_semesters.map do |semester|
      {
        semester: semester.presence || "Unscheduled",
        surveys: grouped[semester].map do |survey|
          responses_map = survey.survey_responses.select { |resp| student_ids.include?(resp.student_id) }.index_by(&:student_id)

          {
            survey: survey,
            rows: students.map do |student|
              {
                student: student,
                advisor: student.advisor,
                response: responses_map[student.student_id]
              }
            end
          }
        end
      }
    end.reject { |block| block[:surveys].blank? }
  end

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
end
