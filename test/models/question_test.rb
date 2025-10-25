# test/models/question_test.rb
require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_seed
  end

  # --- Executive Survey ---
  test "Project Management question in Fall 2025 Executive Survey exists" do
    survey = Survey.find_by(title: "Executive Survey", semester: "Fall 2025")
    assert_not_nil survey, "Executive Survey (Fall 2025) should exist"

    category = survey.categories.find_by(name: "Management Skills")
    assert_not_nil category, "Management Skills category should exist in Executive Survey"

    question = category.questions.find_by(question_text: "Project Management")
    assert_not_nil question, "Project Management question should exist"
    assert question.required, "Project Management question should be required"
  end

  test "Evidence question in Executive Survey is required" do
    survey = Survey.find_by(title: "Executive Survey", semester: "Fall 2025")
    assert_not_nil survey, "Executive Survey should exist"

    evidence_questions = survey.questions.where(question_type: "evidence")
    assert evidence_questions.any?, "There should be at least one evidence question"

    evidence_questions.each do |q|
      assert q.required, "Evidence question '#{q.question_text}' should be required"
    end
  end

  # --- Residential Survey ---
  test "Residential Survey categories and Project Management exist" do
    survey = Survey.find_by(title: "Residential Survey", semester: "Fall 2025")
    assert_not_nil survey, "Residential Survey (Fall 2025) should exist"

    expected_categories = [ "Health Care Environment and Community", "Leadership Skills", "Management Skills", "Analytic and Technical Skills" ]
    actual_names = survey.categories.pluck(:name)
    expected_categories.each do |name|
      assert_includes actual_names, name, "Residential Survey should include category '#{name}'"
    end

    category = survey.categories.find_by(name: "Management Skills")
    assert_not_nil category, "Management Skills category should exist"
    q = category.questions.find_by(question_text: "Project Management")
    assert_not_nil q, "Project Management question should exist in Residential Survey"
    assert q.required, "Project Management should be required"
  end

  # --- Universal sanity checks ---
  test "All evidence questions in both surveys are required" do
    evidence_questions = Question.where(question_type: "evidence")
    assert evidence_questions.count > 0, "There should be evidence questions in seed data"

    evidence_questions.each do |q|
      assert q.required, "Evidence question '#{q.question_text}' should be required"
    end
  end

  test "All multiple choice questions have answer options" do
    mc_questions = Question.where(question_type: "multiple_choice")
    assert mc_questions.count > 0, "There should be multiple choice questions"

    mc_questions.each do |q|
      assert q.answer_options_list.present?, "Multiple choice question '#{q.question_text}' should have answer options"
    end
  end

  test "At least 75% of non-evidence questions are required" do
    non_evidence = Question.where.not(question_type: "evidence")
    # Exclude flexibility questions which are intentionally optional
    non_flexibility = non_evidence.where.not("LOWER(question_text) LIKE ?", "%flexible%work%")

    required_count = non_flexibility.where(required: true).count
    total = non_flexibility.count

    ratio = (required_count.to_f / total) * 100
    assert ratio >= 75, "Expected at least 75% of non-evidence questions (excluding flexibility) to be required, got #{ratio.round(2)}%"
  end

  test "Flexibility questions are optional" do
    flexibility_questions = Question.where("LOWER(question_text) LIKE ?", "%flexible%work%")

    flexibility_questions.each do |q|
      assert_not q.required?, "Flexibility question '#{q.question_text}' should be optional (not required)"
    end
  end
end
