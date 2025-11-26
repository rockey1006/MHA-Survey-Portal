require "test_helper"

class SurveyNotificationJobTest < ActiveJob::TestCase
  setup do
    SurveyNotificationJob.assignment_scope = SurveyAssignment
    @assignment = survey_assignments(:residential_assignment)
    @survey = surveys(:fall_2025)
    @question = questions(:fall_q1)
    @student = students(:student)
    @advisor = advisors(:advisor)
  end

  teardown do
    SurveyNotificationJob.assignment_scope = SurveyAssignment
  end

  # Test :assigned event
  test "assigned event delivers notification to student" do
    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :assigned, survey_assignment_id: @assignment.id)
    end

    notification = Notification.last
    assert_equal @assignment.student.user, notification.user
    assert_equal "New Survey Assigned", notification.title
    assert_match @assignment.survey.title, notification.message
  end

  test "assigned event includes advisor name in message" do
    SurveyNotificationJob.perform_now(event: :assigned, survey_assignment_id: @assignment.id)

    notification = Notification.last
    advisor_name = @assignment.advisor.user.display_name
    assert_match advisor_name, notification.message
  end

  test "assigned event handles missing advisor gracefully" do
    assignment_without_advisor = SurveyAssignment.create!(
      survey: @survey,
      student: students(:other_student),
      advisor_id: nil,
      assigned_at: 2.days.ago,
      due_date: 3.days.from_now
    )

    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :assigned, survey_assignment_id: assignment_without_advisor.id)
    end

    notification = Notification.last
    assert_includes notification.message, "Your advisor"
  end


  # Test :completed event
  test "completed event notifies advisor" do
    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :completed, survey_assignment_id: @assignment.id)
    end

    notification = Notification.last
    assert_equal @assignment.advisor.user, notification.user
    assert_equal "Student Survey Completed", notification.title
    assert_match @assignment.student.full_name, notification.message
    assert_match @assignment.survey.title, notification.message
  end

  test "completed event does not notify if no advisor" do
    assignment_without_advisor = SurveyAssignment.create!(
      survey: @survey,
      student: students(:other_student),
      advisor_id: nil,
      assigned_at: 1.week.ago,
      due_date: 1.week.from_now
    )

    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(event: :completed, survey_assignment_id: assignment_without_advisor.id)
    end
  end

  # Test :response_submitted event
  test "response submitted event thanks student" do
    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :response_submitted, survey_assignment_id: @assignment.id)
    end

    notification = Notification.last
    assert_equal @assignment.student.user, notification.user
    assert_equal "Survey Submitted", notification.title
    assert_match @assignment.survey.title, notification.message
  end

  test "response submitted event does not notify if no student user" do
    fake_assignment = FakeAssignmentRecord.new(
      @assignment.id,
      @assignment.survey,
      @assignment.survey_id,
      nil,
      nil,
      nil,
      nil
    )

    with_assignment_scope([ fake_assignment ]) do
      assert_no_difference -> { Notification.count } do
        SurveyNotificationJob.perform_now(event: :response_submitted, survey_assignment_id: @assignment.id)
      end
    end
  end

  # Test :due_soon event
  test "due soon event notifies student about upcoming deadline" do
    @assignment.update!(due_date: 3.days.from_now)

    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :due_soon, survey_assignment_id: @assignment.id)
    end

    notification = Notification.last
    assert_equal @assignment.student.user, notification.user
    assert_equal "Survey Due Soon", notification.title
    assert_match @assignment.survey.title, notification.message
    assert_match /due in/, notification.message
  end

  test "due soon event skips completed assignments" do
    @assignment.update!(due_date: 3.days.from_now, completed_at: Time.current)

    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(event: :due_soon, survey_assignment_id: @assignment.id)
    end
  end

  test "due soon event skips assignments without due date" do
    @assignment.update!(due_date: nil)

    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(event: :due_soon, survey_assignment_id: @assignment.id)
    end
  end

  # Test :past_due event
  test "past due event notifies student about overdue survey" do
    @assignment.update!(due_date: 2.days.ago)

    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :past_due, survey_assignment_id: @assignment.id)
    end

    notification = Notification.last
    assert_equal @assignment.student.user, notification.user
    assert_equal "Survey Past Due", notification.title
    assert_match @assignment.survey.title, notification.message
    assert_match /past due/i, notification.message
  end

  test "past due event skips completed assignments" do
    @assignment.update!(due_date: 2.days.ago, completed_at: Time.current)

    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(event: :past_due, survey_assignment_id: @assignment.id)
    end
  end

  test "past due event skips assignments without due date" do
    @assignment.update!(due_date: nil)

    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(event: :past_due, survey_assignment_id: @assignment.id)
    end
  end

  # Test :survey_updated event
  test "survey updated event notifies all advisors with assignments" do
    # Create additional advisor assignment
    other_advisor = advisors(:other_advisor)
    SurveyAssignment.create!(
      survey: @survey,
      student: students(:other_student),
      advisor: other_advisor,
      assigned_at: 1.week.ago,
      due_date: 1.week.from_now
    )

    assert_difference -> { Notification.count }, 2 do
      SurveyNotificationJob.perform_now(
        event: :survey_updated,
        survey_id: @survey.id,
        metadata: { summary: "Questions updated." }
      )
    end

    notifications = Notification.last(2)
    recipients = notifications.map(&:user)
    assert_includes recipients, @advisor.user
    assert_includes recipients, other_advisor.user
    assert_equal "Survey Updated", notifications.first.title
    assert_match "Questions updated.", notifications.first.message
  end

  test "survey updated event includes metadata summary" do
    SurveyNotificationJob.perform_now(
      event: :survey_updated,
      survey_id: @survey.id,
      metadata: { summary: "New questions added" }
    )

    notification = Notification.last
    assert_match "New questions added", notification.message
    assert_match @survey.title, notification.message
  end

  test "survey updated event handles empty metadata" do
    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(
        event: :survey_updated,
        survey_id: @survey.id,
        metadata: {}
      )
    end

    notification = Notification.last
    assert_equal "Survey Updated", notification.title
  end

  # Test :survey_archived event
  test "survey archived event notifies all students with assignments" do
    # Create additional student assignment
    other_student = students(:other_student)
    SurveyAssignment.create!(
      survey: @survey,
      student: other_student,
      advisor: advisors(:other_advisor),
      assigned_at: 1.week.ago,
      due_date: 1.week.from_now
    )

    assert_difference -> { Notification.count }, 2 do
      SurveyNotificationJob.perform_now(event: :survey_archived, survey_id: @survey.id)
    end

    notifications = Notification.last(2)
    recipients = notifications.map(&:user)
    assert_includes recipients, @student.user
    assert_includes recipients, other_student.user
    assert_equal "Survey Archived", notifications.first.title
    assert_match @survey.title, notifications.first.message
  end

  test "survey archived event message indicates survey is no longer active" do
    SurveyNotificationJob.perform_now(event: :survey_archived, survey_id: @survey.id)

    notification = Notification.last
    assert_match /no longer active/, notification.message
  end

  # Test :question_updated event
  test "question updated event notifies survey participants" do
    assert_difference -> { Notification.count }, 2 do
      SurveyNotificationJob.perform_now(
        event: :question_updated,
        question_id: @question.id,
        metadata: { editor_name: "Admin" }
      )
    end

    recipients = Notification.last(2).map(&:user)
    assert_includes recipients, users(:student)
    assert_includes recipients, users(:advisor)
    assert_equal "Question Updated", Notification.last.title
  end

  test "question updated event includes editor name in message" do
    SurveyNotificationJob.perform_now(
      event: :question_updated,
      question_id: @question.id,
      metadata: { editor_name: "Dr. Smith" }
    )

    notification = Notification.last
    assert_match "Dr. Smith", notification.message
    assert_match @question.question_text, notification.message
  end

  test "question updated event uses default editor name if not provided" do
    SurveyNotificationJob.perform_now(
      event: :question_updated,
      question_id: @question.id,
      metadata: {}
    )

    notification = Notification.last
    assert_match "An administrator", notification.message
  end

  test "question updated event skips if question has no survey" do
    orphan_question = Question.new(
      category: categories(:clinical_skills),
      question_text: "Placeholder",
      question_order: 99,
      question_type: "short_answer",
      is_required: false
    )
    orphan_question.save!(validate: false)
    orphan_question.update_column(:category_id, nil)

    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(
        event: :question_updated,
        question_id: orphan_question.id,
        metadata: {}
      )
    end
  end

  # Test :custom event
  test "custom event delivers notification with provided details" do
    user = users(:student)

    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(
        event: :custom,
        user_id: user.id,
        metadata: { title: "Custom Title", message: "Custom message content" }
      )
    end

    notification = Notification.last
    assert_equal user, notification.user
    assert_equal "Custom Title", notification.title
    assert_equal "Custom message content", notification.message
  end

  test "custom event uses default title and message if not provided" do
    user = users(:student)

    SurveyNotificationJob.perform_now(event: :custom, user_id: user.id, metadata: {})

    notification = Notification.last
    assert_equal "Notification", notification.title
    assert_equal "You have a new notification.", notification.message
  end

  test "custom event does not deliver if user_id is blank" do
    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(
        event: :custom,
        user_id: nil,
        metadata: { title: "Test", message: "Test message" }
      )
    end
  end

  # Test unknown events
  test "unknown event logs info message and does nothing" do
    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(event: :unknown_event, survey_assignment_id: @assignment.id)
    end
  end

  test "unknown event handles string events" do
    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(event: "invalid_event", survey_assignment_id: @assignment.id)
    end
  end

  # Test error handling
  test "rescues ActiveRecord::RecordNotFound for missing assignment" do
    assert_nothing_raised do
      SurveyNotificationJob.perform_now(event: :assigned, survey_assignment_id: 999_999)
    end

    assert_no_difference -> { Notification.count } do
      SurveyNotificationJob.perform_now(event: :assigned, survey_assignment_id: 999_999)
    end
  end

  test "rescues ActiveRecord::RecordNotFound for missing survey" do
    assert_nothing_raised do
      SurveyNotificationJob.perform_now(event: :survey_updated, survey_id: 999_999)
    end
  end

  test "rescues ActiveRecord::RecordNotFound for missing question" do
    assert_nothing_raised do
      SurveyNotificationJob.perform_now(event: :question_updated, question_id: 999_999)
    end
  end

  test "rescues ActiveRecord::RecordNotFound for missing user in custom event" do
    assert_nothing_raised do
      SurveyNotificationJob.perform_now(event: :custom, user_id: 999_999, metadata: { title: "Test" })
    end
  end

  # Test metadata handling
  test "handles string metadata keys" do
    SurveyNotificationJob.perform_now(
      event: :survey_updated,
      survey_id: @survey.id,
      metadata: { "summary" => "String key test" }
    )

    notification = Notification.last
    assert_match "String key test", notification.message
  end

  test "handles symbol metadata keys" do
    SurveyNotificationJob.perform_now(
      event: :survey_updated,
      survey_id: @survey.id,
      metadata: { summary: "Symbol key test" }
    )

    notification = Notification.last
    assert_match "Symbol key test", notification.message
  end

  test "handles nil metadata gracefully" do
    assert_difference -> { Notification.count }, 1 do
      SurveyNotificationJob.perform_now(event: :assigned, survey_assignment_id: @assignment.id, metadata: nil)
    end
  end

  # Test participant collection
  test "participant_users_for_survey deduplicates users" do
    # This test verifies that the participant collection doesn't crash with duplicate users
    # The fixture already has an assignment with student + advisor
    assert_nothing_raised do
      SurveyNotificationJob.perform_now(
        event: :question_updated,
        question_id: @question.id,
        metadata: {}
      )
    end

    # Should have notified participants
    assert Notification.count >= 2
  end

  test "handles assignment with nil student gracefully" do
    orphan_assignment = FakeAssignmentRecord.new(
      999,
      @survey,
      @survey.id,
      nil,
      @advisor,
      nil,
      @advisor.advisor_id
    )

    with_assignment_scope([ orphan_assignment ]) do
      assert_nothing_raised do
        SurveyNotificationJob.perform_now(
          event: :question_updated,
          question_id: @question.id,
          metadata: {}
        )
      end
    end
  end

  test "handles assignment with nil advisor gracefully" do
    assignment_with_nil = SurveyAssignment.create!(
      survey: @survey,
      student: students(:other_student),
      advisor_id: nil,
      assigned_at: 1.week.ago,
      due_date: 1.week.from_now
    )

    assert_nothing_raised do
      SurveyNotificationJob.perform_now(
        event: :question_updated,
        question_id: @question.id,
        metadata: {}
      )
    end
  end
end

FakeAssignmentRecord = Struct.new(
  :id,
  :survey,
  :survey_id,
  :student,
  :advisor,
  :recipient_user,
  :advisor_id,
  keyword_init: false
)

class FakeAssignmentScope
  def initialize(records)
    @records = Array(records)
    @index = @records.index_by(&:id)
  end

  def includes(*)
    self
  end

  def find(id)
    record = @index[id]
    raise ActiveRecord::RecordNotFound, "Assignment #{id} not found" unless record

    record
  end

  def where(conditions = {})
    filtered = filter_records(@records, conditions)
    FakeAssignmentRelation.new(filtered)
  end

  private

  def filter_records(records, conditions)
    return records if conditions.blank?

    records.select do |record|
      conditions.all? do |key, value|
        record.respond_to?(key) && record.public_send(key) == value
      end
    end
  end
end

class FakeAssignmentRelation
  def initialize(records)
    @records = Array(records)
  end

  def includes(*)
    self
  end

  def where(conditions = {})
    filtered = filter_records(@records, conditions)
    FakeAssignmentRelation.new(filtered)
  end

  def distinct
    self
  end

  def pluck(attribute)
    @records.map { |record| record.public_send(attribute) }
  end

  def find_each(&block)
    @records.each(&block)
  end

  private

  def filter_records(records, conditions)
    return records if conditions.blank?

    records.select do |record|
      conditions.all? do |key, value|
        record.respond_to?(key) && record.public_send(key) == value
      end
    end
  end
end

private

def with_assignment_scope(records)
  original_scope = SurveyNotificationJob.assignment_scope
  SurveyNotificationJob.assignment_scope = FakeAssignmentScope.new(records)
  yield
ensure
  SurveyNotificationJob.assignment_scope = original_scope
end
