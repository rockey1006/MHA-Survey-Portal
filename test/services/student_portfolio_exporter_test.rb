require "test_helper"

class StudentPortfolioExporterTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @student = students(:student)
    @question = Question.create!(
      category: categories(:clinical_skills),
      question_text: StudentPortfolioExporter::PORTFOLIO_QUESTION_TEXT,
      question_order: 50,
      question_type: "evidence",
      is_required: true
    )
    StudentQuestion.create!(
      student: @student,
      question: @question,
      response_value: "https://sites.google.com/example/student"
    )
  end

  test "workbook exports uin in the student id column" do
    exporter = StudentPortfolioExporter.new(actor_user: @admin, params: { q: @student.user.display_name })
    workbook = exporter.workbook.workbook
    sheet = workbook.worksheets.first

    assert_equal [ "UIN", "Name", "Email", "Track", "Cohort", "Advisor", "Google Sites URL", "Submitted At" ],
                 sheet.rows.first.cells.map(&:value)
    assert_equal @student.uin, sheet.rows.second.cells.first.value
  end
end
