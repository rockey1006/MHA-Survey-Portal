require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "can create multiple feedback rows and accept numeric average_score" do
  user = User.create!(email: "stu@example.com", name: "Student One", role: "student")
  # User creation auto-creates a student profile via after_commit; use it.
  student = user.student_profile
  adv_user = User.create!(email: "adv@example.com", name: "Advisor One", role: "advisor")
  advisor = adv_user.advisor_profile
  survey = Survey.new(title: "T", semester: "Fall 2025")
  cat = survey.categories.build(name: "C")
  cat.questions.build(question_text: "Q1", question_order: 1, question_type: "short_answer")
  survey.save!
  cat = survey.categories.first

    fb1 = Feedback.new(student_id: student.student_id, advisor_id: advisor.advisor_id, survey_id: survey.id, category_id: cat.id, average_score: 5.0)
    assert fb1.valid?
    assert fb1.save

    fb2 = Feedback.new(student_id: student.student_id, advisor_id: advisor.advisor_id, survey_id: survey.id, category_id: cat.id, comments: "Note")
    assert fb2.valid?
    assert fb2.save
  end
end
