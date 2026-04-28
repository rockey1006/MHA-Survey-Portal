# frozen_string_literal: true

require "caxlsx"

class StudentPortfolioExporter
  PORTFOLIO_QUESTION_TEXT = "Please provide a link to your MHA Portfolio (Google Sites) as evidence for this survey."

  def initialize(actor_user:, params: {})
    @actor_user = actor_user
    @params = params.to_h.with_indifferent_access
  end

  def students
    @students ||= begin
      scope = base_scope.includes(:user, advisor: :user).left_outer_joins(:user)
      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
        scope = scope.where("users.name ILIKE :term OR users.email ILIKE :term OR students.uin ILIKE :term", term: term)
      end
      if params[:track].present?
        track_key = ProgramTrack.canonical_key(params[:track])
        scope = scope.where("LOWER(students.track) = ?", track_key) if track_key.present?
      end
      scope = scope.where(program_year: params[:program_year]) if params[:program_year].present?
      scope.order(Arel.sql("LOWER(COALESCE(users.name, users.email, '')) ASC"), :student_id)
    end
  end

  def rows
    @rows ||= begin
      answers = latest_portfolio_answers
      students.map do |student|
        answer = answers[student.student_id]
        {
          student_id: student.student_id,
          name: student.user&.display_name,
          email: student.user&.email,
          uin: student.uin,
          track: student.track,
          program_year: student.program_year,
          advisor: student.advisor&.display_name,
          portfolio_url: answer&.response_value,
          submitted_at: answer&.updated_at
        }
      end
    end
  end

  def workbook
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Portfolio URLs") do |sheet|
      sheet.add_row [ "UIN", "Name", "Email", "Track", "Cohort", "Advisor", "Google Sites URL", "Submitted At" ]
      rows.each do |row|
        sheet.add_row [
          row[:uin].to_s,
          row[:name],
          row[:email],
          row[:track],
          row[:program_year],
          row[:advisor],
          row[:portfolio_url],
          row[:submitted_at]
        ], types: [
          :string,
          :string,
          :string,
          :string,
          :string,
          :string,
          :string,
          :string
        ]
      end
    end
    package
  end

  private

  attr_reader :actor_user, :params

  def base_scope
    if actor_user&.role_advisor?
      Student.where(advisor_id: actor_user.advisor_profile&.advisor_id)
    else
      Student.all
    end
  end

  def latest_portfolio_answers
    student_ids = students.map(&:student_id)
    return {} if student_ids.empty?

    StudentQuestion
      .joins(:question)
      .where(student_id: student_ids, questions: { question_text: PORTFOLIO_QUESTION_TEXT })
      .select("student_questions.*")
      .order("student_questions.student_id ASC, student_questions.updated_at DESC, student_questions.id DESC")
      .each_with_object({}) do |answer, lookup|
        lookup[answer.student_id] ||= answer
      end
  end
end
