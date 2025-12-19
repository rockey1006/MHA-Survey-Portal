require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "can create multiple feedback rows and accept numeric average_score" do
    user = User.create!(email: "stu@example.com", name: "Student One", role: "student")
    # User creation auto-creates a student profile via after_commit; use it.
    student = user.student_profile

    adv_user = User.create!(email: "adv@example.com", name: "Advisor One", role: "advisor")
    advisor = adv_user.advisor_profile

    survey = Survey.new(title: "T", semester: "Fall 2025")
    category = survey.categories.build(name: "C")
    category.questions.build(question_text: "Q1", question_order: 1, question_type: "short_answer")
    survey.save!
    category = survey.categories.first

    fb1 = Feedback.new(student_id: student.student_id,
                       advisor_id: advisor.advisor_id,
                       survey_id: survey.id,
                       category_id: category.id,
                       average_score: 5.0)
    assert fb1.valid?
    assert fb1.save

    fb2 = Feedback.new(student_id: student.student_id,
                       advisor_id: advisor.advisor_id,
                       survey_id: survey.id,
                       category_id: category.id,
                       comments: "Note")
    assert fb2.valid?
    assert fb2.save

    assert_equal 2, Feedback.where(student_id: student.student_id, survey_id: survey.id).count
  end

  test "average_score must be within 0..5 when provided" do
    user = User.create!(email: "stu-range@example.com", name: "Student Range", role: "student")
    student = user.student_profile

    adv_user = User.create!(email: "adv-range@example.com", name: "Advisor Range", role: "advisor")
    advisor = adv_user.advisor_profile

    survey = Survey.new(title: "Range Survey", semester: "Fall 2025")
    category = survey.categories.build(name: "C")
    category.questions.build(question_text: "Q1", question_order: 1, question_type: "short_answer")
    survey.save!

    base_attrs = {
      student_id: student.student_id,
      advisor_id: advisor.advisor_id,
      survey_id: survey.id,
      category_id: survey.categories.first.id
    }

    assert Feedback.new(base_attrs.merge(average_score: 0)).valid?
    assert Feedback.new(base_attrs.merge(average_score: 5)).valid?
    assert Feedback.new(base_attrs.merge(average_score: 4.8)).valid?

    refute Feedback.new(base_attrs.merge(average_score: -0.1)).valid?
    refute Feedback.new(base_attrs.merge(average_score: 5.1)).valid?
  end
end
