require "test_helper"

class StudentPortfolioExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @advisor = users(:advisor)
    @student = students(:student)
    @other_student = students(:other_student)
    @student.update!(advisor_id: @advisor.id)
    @other_student.update!(advisor_id: users(:other_advisor).id)
    @portfolio_question = Question.create!(
      category: categories(:clinical_skills),
      question_text: StudentPortfolioExporter::PORTFOLIO_QUESTION_TEXT,
      question_order: 20,
      question_type: "evidence",
      is_required: true
    )
    StudentQuestion.create!(
      student: @student,
      question: @portfolio_question,
      response_value: "https://sites.google.com/example/student"
    )
    StudentQuestion.create!(
      student: @other_student,
      question: @portfolio_question,
      response_value: "https://sites.google.com/example/other"
    )
  end

  test "admin can view portfolio export page" do
    sign_in @admin

    get student_portfolio_export_path

    assert_response :success
    assert_includes response.body, "Portfolio Export"
    assert_includes response.body, "https://sites.google.com/example/student"
    assert_includes response.body, "https://sites.google.com/example/other"
  end

  test "advisor sees only assigned advisees" do
    sign_in @advisor

    get student_portfolio_export_path

    assert_response :success
    assert_includes response.body, "https://sites.google.com/example/student"
    refute_includes response.body, "https://sites.google.com/example/other"
  end

  test "export downloads xlsx" do
    sign_in @admin

    get download_student_portfolio_export_path

    assert_response :success
    assert_includes response.headers["Content-Disposition"], ".xlsx"
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
  end

  test "student cannot access portfolio export" do
    sign_in users(:student)

    get student_portfolio_export_path

    assert_redirected_to dashboard_path
  end
end
