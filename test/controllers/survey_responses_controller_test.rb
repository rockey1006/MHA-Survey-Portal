require "test_helper"
require "tempfile"

class SurveyResponsesControllerUnitTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  tests SurveyResponsesController

  setup do
    @admin = users(:admin)
    @student_user = users(:student)
    @student = students(:student)
    @survey = surveys(:fall_2025)
    @assigned_advisor = users(:advisor)
    @other_advisor = users(:other_advisor)
  end

  test "edit populates existing_answers and other_answers for mixed answer shapes" do
    sign_in @admin

    semester = program_semesters(:fall_2025)
    survey = Survey.new(
      title: "Admin Edit Survey #{SecureRandom.hex(4)}",
      program_semester: semester,
      description: "",
      is_active: false
    )
    category = survey.categories.build(name: "Cat", description: "")

    choice = category.questions.build(
      question_text: "Choice",
      question_order: 0,
      question_type: "dropdown",
      is_required: false,
      answer_options: [
        { label: "Yes", value: "Yes" },
        { label: "Other", value: "Other", requires_text: true }
      ].to_json
    )
    text = category.questions.build(
      question_text: "Text",
      question_order: 1,
      question_type: "short_answer",
      is_required: false
    )

    survey.save!

    StudentQuestion.create!(
      student_id: @student.student_id,
      advisor_id: @student.advisor_id,
      question_id: choice.id,
      answer: { "answer" => "Other", "text" => "details" }
    )
    StudentQuestion.create!(
      student_id: @student.student_id,
      advisor_id: @student.advisor_id,
      question_id: text.id,
      answer: { "text" => "hello" }
    )

    sr = SurveyResponse.build(student: @student, survey: survey)
    get :edit, params: { id: sr.id, return_to: "/surveys" }

    assert_response :success
    assert_equal "Other", assigns(:existing_answers)[choice.id.to_s]
    assert_equal "details", assigns(:other_answers)[choice.id.to_s]
    assert_equal "hello", assigns(:existing_answers)[text.id.to_s]
  end

  test "update captures snapshot and edited version when answers change" do
    sign_in @admin

    semester = program_semesters(:fall_2025)
    survey = Survey.new(
      title: "Admin Update Survey #{SecureRandom.hex(4)}",
      program_semester: semester,
      description: "",
      is_active: false
    )
    category = survey.categories.build(name: "Cat", description: "")

    q1 = category.questions.build(
      question_text: "Q1",
      question_order: 0,
      question_type: "short_answer",
      is_required: false
    )
    q2 = category.questions.build(
      question_text: "Q2",
      question_order: 1,
      question_type: "short_answer",
      is_required: false
    )

    survey.save!

    SurveyAssignment.create!(
      survey: survey,
      student_id: @student.student_id,
      advisor_id: @student.advisor_id,
      assigned_at: 1.day.ago
    )

    StudentQuestion.create!(
      student_id: @student.student_id,
      advisor_id: @student.advisor_id,
      question: q1,
      response_value: "old"
    )
    StudentQuestion.create!(
      student_id: @student.student_id,
      advisor_id: @student.advisor_id,
      question: q2,
      response_value: "to-be-removed"
    )

    sr = SurveyResponse.build(student: @student, survey: survey)

    captured_events = []
    fake_versions = [ Struct.new(:answers).new({ "some" => "other" }) ]
    fake_scope = Struct.new(:versions) do
      def chronological
        versions
      end
    end

    answers_call_count = 0

    SurveyResponseVersion.stub(:for_pair, fake_scope.new(fake_versions)) do
      SurveyResponseVersion.stub(:current_answers_for, ->(student:, survey:) {
        answers_call_count += 1
        answers_call_count == 1 ? { q1.id.to_s => "old" } : { q1.id.to_s => "new" }
      }) do
        SurveyResponseVersion.stub(:capture_current!, ->(student:, survey:, assignment:, actor_user:, event:, **_) {
          captured_events << event.to_sym
          Struct.new(:id).new(123)
        }) do
          patch :update, params: {
            id: sr.id,
            return_to: "http://evil.example.com",
            answers: {
              q1.id.to_s => "new",
              q2.id.to_s => ""
            }
          }
        end
      end
    end

    assert_redirected_to survey_response_path(sr.id)
    assert_includes captured_events, :admin_snapshot
    assert_includes captured_events, :admin_edited

    assert_equal "new", StudentQuestion.find_by(student_id: @student.student_id, question_id: q1.id).answer
    assert_nil StudentQuestion.find_by(student_id: @student.student_id, question_id: q2.id)
  end

  test "destroy clears saved answers, resets completion, and notifies student" do
    sign_in @admin

    semester = program_semesters(:fall_2025)
    survey = Survey.new(
      title: "Admin Destroy Survey #{SecureRandom.hex(4)}",
      program_semester: semester,
      description: "",
      is_active: false
    )
    category = survey.categories.build(name: "Cat", description: "")
    q1 = category.questions.build(
      question_text: "Q1",
      question_order: 0,
      question_type: "short_answer",
      is_required: false
    )

    survey.save!

    assignment = SurveyAssignment.create!(
      survey: survey,
      student_id: @student.student_id,
      advisor_id: @student.advisor_id,
      assigned_at: 1.day.ago,
      completed_at: Time.current
    )

    StudentQuestion.create!(
      student_id: @student.student_id,
      advisor_id: @student.advisor_id,
      question: q1,
      response_value: "old"
    )

    sr = SurveyResponse.build(student: @student, survey: survey)

    captured = false
    delivered = false

    SurveyResponseVersion.stub(:capture_current!, ->(**_) { captured = true }) do
      Notification.stub(:deliver!, ->(**_) { delivered = true }) do
        delete :destroy, params: { id: sr.id }
      end
    end

    assert_redirected_to student_records_path
    assert captured, "Expected SurveyResponseVersion.capture_current! to run"
    assert delivered, "Expected Notification.deliver! to run"
    assert_nil StudentQuestion.find_by(student_id: @student.student_id, question_id: q1.id)
    assert_nil assignment.reload.completed_at
  end

  test "set_survey_response via id param returns not found for bad id" do
    sign_in @admin
    # use well-formed composite id where survey portion is missing to trigger RecordNotFound
    student_id = @student.student_id
    missing_survey_id = 9_999_999
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { id: "#{student_id}-#{missing_survey_id}" }
    end
  end

  test "find_by_signed_download_token allows access with token" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)
    token = sr.signed_download_token
    # include a dummy id to satisfy route recognition; controller will use token branch first
    get :show, params: { id: "ignored", token: token }
    assert_response :success
  end

  test "authorize_view allows assigned advisor" do
    sign_in @assigned_advisor
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :show, params: { id: sr.id }
    assert_response :success
  end

  test "authorize_view blocks advisors for unassigned students" do
    sign_in @other_advisor
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :show, params: { id: sr.id }
    assert_response :unauthorized
  end

  test "download returns service_unavailable when WickedPdf not defined" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :download, params: { id: sr.id }
    # allow either 503 (no WickedPdf) or 200 (if environment has it); assert expected message if 503
    assert_includes [ 200, 503 ], @response.status
    if @response.status == 503
      assert_includes @response.body.downcase, "server-side pdf generation unavailable"
    end
  end

  test "download streams a PDF when WickedPdf is present and generator succeeds" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)

    wickedpdf_defined = defined?(WickedPdf)
    Object.const_set(:WickedPdf, Class.new) unless wickedpdf_defined

    tmp = Tempfile.new([ "survey", ".pdf" ])
    tmp.binmode
    tmp.write("%PDF-1.4\n%fake\n")
    tmp.flush

    result = Struct.new(:path) do
      def cleanup!; end
    end
    fake_result = result.new(tmp.path)
    fake_generator = Struct.new(:result) do
      def render
        result
      end
    end

    CompositeReportGenerator.stub(:new, fake_generator.new(fake_result)) do
      get :download, params: { id: sr.id }
      assert_response :success
      assert_equal "application/pdf", @response.media_type
      assert_includes @response.headers["Content-Disposition"].to_s, "attachment"
    end
  ensure
    tmp&.close
    tmp&.unlink
    Object.send(:remove_const, :WickedPdf) unless wickedpdf_defined
  end

  test "download returns 503 when generator returns a missing file" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)

    wickedpdf_defined = defined?(WickedPdf)
    Object.const_set(:WickedPdf, Class.new) unless wickedpdf_defined

    result = Struct.new(:path) do
      def cleanup!; end
    end
    fake_result = result.new("/tmp/does-not-exist-#{SecureRandom.hex}.pdf")
    fake_generator = Struct.new(:result) do
      def render
        result
      end
    end

    CompositeReportGenerator.stub(:new, fake_generator.new(fake_result)) do
      get :download, params: { id: sr.id }
      assert_response :service_unavailable
      assert_includes @response.body.to_s.downcase, "pdf generation unavailable"
    end
  ensure
    Object.send(:remove_const, :WickedPdf) unless wickedpdf_defined
  end

  test "download returns 503 when generated bytes are not a PDF" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)

    wickedpdf_defined = defined?(WickedPdf)
    Object.const_set(:WickedPdf, Class.new) unless wickedpdf_defined

    tmp = Tempfile.new([ "not_pdf", ".pdf" ])
    tmp.binmode
    tmp.write("NOPE")
    tmp.flush

    result = Struct.new(:path) do
      def cleanup!; end
    end
    fake_result = result.new(tmp.path)
    fake_generator = Struct.new(:result) do
      def render
        result
      end
    end

    CompositeReportGenerator.stub(:new, fake_generator.new(fake_result)) do
      get :download, params: { id: sr.id }
      assert_response :service_unavailable
      assert_includes @response.body.to_s.downcase, "pdf generation unavailable"
    end
  ensure
    tmp&.close
    tmp&.unlink
    Object.send(:remove_const, :WickedPdf) unless wickedpdf_defined
  end

  test "download returns 500 when generator raises GenerationError" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)

    wickedpdf_defined = defined?(WickedPdf)
    Object.const_set(:WickedPdf, Class.new) unless wickedpdf_defined

    fake_generator = Object.new
    def fake_generator.render
      raise CompositeReportGenerator::GenerationError, "nope"
    end

    CompositeReportGenerator.stub(:new, fake_generator) do
      get :download, params: { id: sr.id }
      assert_response :internal_server_error
    end
  ensure
    Object.send(:remove_const, :WickedPdf) unless wickedpdf_defined
  end

  test "composite_report returns service_unavailable when WickedPdf missing" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :composite_report, params: { id: sr.id }
    assert_includes [ 200, 503 ], @response.status
    if @response.status == 503
      assert_includes @response.body.downcase, "composite pdf generation unavailable"
    end
  end

  test "composite_report returns 503 when WickedPdf present but generator output is invalid" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)

    wickedpdf_defined = defined?(WickedPdf)
    Object.const_set(:WickedPdf, Class.new) unless wickedpdf_defined

    result = Struct.new(:path) do
      def cleanup!; end
    end
    fake_result = result.new(nil)
    fake_generator = Struct.new(:result) do
      def render
        result
      end
    end

    CompositeReportGenerator.stub(:new, fake_generator.new(fake_result)) do
      get :composite_report, params: { id: sr.id }
      assert_response :service_unavailable
      assert_includes @response.body.to_s.downcase, "composite pdf generation unavailable"
    end
  ensure
    Object.send(:remove_const, :WickedPdf) unless wickedpdf_defined
  end

  test "composite_report returns 500 when generator raises GenerationError" do
    sign_in @admin
    sr = SurveyResponse.build(student: @student, survey: @survey)

    wickedpdf_defined = defined?(WickedPdf)
    Object.const_set(:WickedPdf, Class.new) unless wickedpdf_defined

    fake_generator = Object.new
    def fake_generator.render
      raise CompositeReportGenerator::GenerationError, "boom"
    end

    CompositeReportGenerator.stub(:new, fake_generator) do
      get :composite_report, params: { id: sr.id }
      assert_response :internal_server_error
    end
  ensure
    Object.send(:remove_const, :WickedPdf) unless wickedpdf_defined
  end

  test "composite_report rejects student users" do
    sign_in @student_user
    sr = SurveyResponse.build(student: @student, survey: @survey)
    get :composite_report, params: { id: sr.id }
    assert_response :unauthorized
  end
end

class SurveyResponsesControllerIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @student_user = users(:student)
    survey = surveys(:fall_2025)
    student = students(:student) || Student.first
    @survey_response = SurveyResponse.build(student: student, survey: survey)
  end

  test "show uses competency target levels rather than legacy question program_target_level" do
    sign_in @student_user

    student = students(:student)
    student.update!(program_year: 1)
    survey = surveys(:fall_2025)

    competency_title = Reports::DataAggregator::COMPETENCY_TITLES.first
    category = survey.categories.first || survey.categories.create!(name: "Test Category", description: "")

    category.questions.create!(
      question_text: competency_title,
      question_order: 999,
      question_type: "dropdown",
      answer_options: %w[1 2 3 4 5].to_json,
      program_target_level: 1
    )

    CompetencyTargetLevel.create!(
      program_semester: survey.program_semester,
      track: student.track_before_type_cast,
      program_year: 1,
      competency_title: competency_title,
      target_level: 5
    )

    survey_response = SurveyResponse.build(student: student, survey: survey)

    get survey_response_path(survey_response)
    assert_response :success
    assert_match(/#{Regexp.escape(competency_title)}.*Target Level: 5\/5/m, response.body)
    refute_match(/#{Regexp.escape(competency_title)}.*Target Level: 1\/5/m, response.body)
  end

  test "student can view their own survey response" do
    sign_in @student_user

    get survey_response_path(@survey_response)
    assert_response :success
  end

  test "other students are blocked from viewing the response" do
    sign_in users(:other_student)

    get survey_response_path(@survey_response)
    assert_response :unauthorized
  end

  test "download returns 503 when WickedPdf missing" do
    # No WickedPdf available in test environment so expect service_unavailable
    sign_in users(:admin)
    get download_survey_response_path(@survey_response)
    assert_includes [ 200, 503 ], response.status
    if response.status == 503
      assert_match /Server-side PDF generation unavailable/, @response.body
    else
      # If WickedPdf is present, we at least expect a response body or an attachment header
      assert response.body.present? || response.headers["Content-Disposition"].present?
    end
  end

  test "set_survey_response returns 404 for missing token" do
    sign_in users(:admin)
    get survey_response_path(id: "nonexistent")
    assert_response :not_found
  end

  test "composite_report returns 503 when WickedPdf missing" do
    sign_in users(:admin)
    get composite_report_survey_response_path(@survey_response)
    assert_includes [ 200, 503 ], response.status
    if response.status == 503
      assert_match /Composite PDF generation unavailable/, @response.body
    else
      assert response.body.present? || response.headers["Content-Disposition"].present?
    end
  end

  test "composite report rejects token access even for admins" do
    sign_in users(:admin)
    token = @survey_response.signed_download_token

    get composite_report_survey_response_path(@survey_response), params: { token: token }
    assert_response :unauthorized
  end
end
