require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "saving score/comments enqueues feedback notification job" do
    student_user = User.create!(email: "stu-notify@example.com", name: "Student Notify", role: "student")
    student = student_user.student_profile

    advisor_user = User.create!(email: "adv-notify@example.com", name: "Advisor Notify", role: "advisor")
    advisor = advisor_user.advisor_profile

    survey = Survey.new(title: "Notify Survey", semester: "Fall 2025")
    category = survey.categories.build(name: "C")
    category.questions.build(question_text: "Q1", question_order: 1, question_type: "short_answer")
    survey.save!

    SurveyAssignment.create!(
      survey: survey,
      student: student,
      advisor: advisor,
      assigned_at: Time.current
    )

    fb = nil
    assert_enqueued_jobs 1, only: SurveyNotificationJob do
      fb = Feedback.create!(
        student_id: student.student_id,
        advisor_id: advisor.advisor_id,
        survey_id: survey.id,
        category_id: survey.categories.first.id,
        average_score: 4,
        comments: "Nice work"
      )
    end

    assert_enqueued_with(job: SurveyNotificationJob, args: [ { event: :feedback_received, feedback_id: fb.id } ])
  end

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

  test "average_score must be within 1..5 when provided" do
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

    assert Feedback.new(base_attrs.merge(average_score: 1)).valid?
    assert Feedback.new(base_attrs.merge(average_score: 5)).valid?
    assert Feedback.new(base_attrs.merge(average_score: 4.8)).valid?

    refute Feedback.new(base_attrs.merge(average_score: -0.1)).valid?
    refute Feedback.new(base_attrs.merge(average_score: 0)).valid?
    refute Feedback.new(base_attrs.merge(average_score: 5.1)).valid?
  end

  test "comments length is limited" do
    user = User.create!(email: "stu-comments@example.com", name: "Student Comments", role: "student")
    student = user.student_profile

    adv_user = User.create!(email: "adv-comments@example.com", name: "Advisor Comments", role: "advisor")
    advisor = adv_user.advisor_profile

    survey = Survey.new(title: "Comments Survey", semester: "Fall 2025")
    category = survey.categories.build(name: "C")
    category.questions.build(question_text: "Q1", question_order: 1, question_type: "short_answer")
    survey.save!

    base_attrs = {
      student_id: student.student_id,
      advisor_id: advisor.advisor_id,
      survey_id: survey.id,
      category_id: survey.categories.first.id
    }

    assert Feedback.new(base_attrs.merge(comments: "a" * Feedback::COMMENTS_MAX_LENGTH)).valid?

    too_long = Feedback.new(base_attrs.merge(comments: "a" * (Feedback::COMMENTS_MAX_LENGTH + 1)))
    refute too_long.valid?
    assert_includes too_long.errors[:comments], "is too long (maximum is #{Feedback::COMMENTS_MAX_LENGTH} characters)"
  end
end
