require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @adv_user = users(:advisor)
    @advisor = @adv_user.advisor_profile

    @student_user = users(:student)
    @student = students(:student) || Student.first

    @survey = (defined?(surveys) && surveys(:fall_2025) rescue nil)
    unless @survey
      @survey = Survey.create!(title: "Survey X", semester: "Fall")
      c1 = @survey.categories.create!(name: "Cat A")
      c1.questions.create!(question_text: "Q A1", question_order: 1, question_type: "short_answer")
      c2 = @survey.categories.create!(name: "Cat B")
      c2.questions.create!(question_text: "Q B1", question_order: 1, question_type: "short_answer")
    end

    # Ensure survey has at least two categories (fixtures may not include them)
    if @survey.categories.count < 2
      (2 - @survey.categories.count).times do |i|
        c = @survey.categories.create!(name: "Cat #{i + 1}")
        c.questions.create!(question_text: "Q #{i + 1}", question_order: i + 1, question_type: "short_answer")
      end
      @survey.reload
    end
    @cat1, @cat2 = @survey.categories.order(:id).limit(2)
    @feedback = feedbacks(:advisor_feedback)

    sign_in @adv_user
  end

  # === Index Action ===

  test "index displays all feedbacks" do
    get feedbacks_path
    assert_response :success
  end

  # === Show Action ===

  test "show displays feedback" do
    get feedback_path(@feedback)
    assert_response :success
  end

  # === New Action ===

  test "new renders form with survey and student context" do
    get new_feedback_path, params: { survey_id: @survey.id, student_id: @student.student_id }
    assert_response :success
  end

  test "new loads survey response context" do
    # Create student question responses
    q = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")
    StudentQuestion.find_or_create_by!(student_id: @student.student_id, question_id: q.id) do |sq|
      sq.response_text = "Test response"
    end

    get new_feedback_path, params: { survey_id: @survey.id, student_id: @student.student_id }
    assert_response :success
  end

  # === Edit Action ===

  test "edit renders form" do
    get edit_feedback_path(@feedback)
    assert_response :success
  end

  # === Create Action - Batch Ratings ===

  test "batch create creates feedback records and redirects" do
    # Controller now expects ratings keyed by question id (per-question feedback)
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Auto Q1", question_order: 1, question_type: "short_answer")
    q2 = @cat2.questions.first || @cat2.questions.create!(question_text: "Auto Q2", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "4", comments: "Good" },
        q2.id.to_s => { average_score: "3", comments: "Ok" }
      }
    }

    before_count = Feedback.where(student_id: @student.student_id, survey_id: @survey.id).count
    post feedbacks_path, params: params

    assert_response :redirect
    assert_redirected_to student_records_path
    after_count = Feedback.where(student_id: @student.student_id, survey_id: @survey.id).count
    assert_equal before_count + 2, after_count
  end

  test "batch create with only score" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "5", comments: "" }
      }
    }

    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: params
    end

    assert_redirected_to student_records_path
    feedback = Feedback.order(:created_at).last
    assert_equal 5.0, feedback.average_score
    assert_nil feedback.comments
  end

  test "batch create with only comments" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "", comments: "Great work!" }
      }
    }

    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: params
    end

    assert_redirected_to student_records_path
    feedback = Feedback.order(:created_at).last
    assert_nil feedback.average_score
    assert_equal "Great work!", feedback.comments
  end

  test "batch create skips empty ratings" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")
    q2 = @cat2.questions.first || @cat2.questions.create!(question_text: "Q2", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "4", comments: "Good" },
        q2.id.to_s => { average_score: "", comments: "" } # Empty, should be skipped
      }
    }

    assert_difference "Feedback.count", 1 do # Only 1 should be created
      post feedbacks_path, params: params
    end

    assert_redirected_to student_records_path
  end

  test "batch create updates existing feedback" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    # Create initial feedback
    existing = Feedback.create!(
      student_id: @student.student_id,
      survey_id: @survey.id,
      question_id: q1.id,
      category_id: @cat1.id,
      advisor_id: @advisor.advisor_id,
      average_score: 3,
      comments: "Initial"
    )

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { id: existing.id, average_score: "5", comments: "Updated" }
      }
    }

    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: params
    end

    existing.reload
    assert_equal 5.0, existing.average_score
    assert_equal "Updated", existing.comments
  end

  test "batch create with validation errors rolls back transaction" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "invalid", comments: "Test" }
      }
    }

    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: params
    end

    assert_response :unprocessable_entity
  end

  test "batch create rejects scores outside 1-5" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "6", comments: "Too high" }
      }
    }

    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: params
    end

    assert_response :unprocessable_entity
  end

  test "batch create rejects 0 score" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "0", comments: "Not assessable" }
      }
    }

    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: params
    end

    assert_response :unprocessable_entity
  end

  test "batch create with no valid ratings returns error" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "", comments: "" } # Empty
      }
    }

    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: params
    end

    assert_response :unprocessable_entity
  end

  test "batch create responds with JSON on success" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "4", comments: "Good" }
      }
    }

    post feedbacks_path, params: params, as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_kind_of Array, json
  end

  test "batch create responds with JSON on validation error" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { average_score: "invalid", comments: "Test" }
      }
    }

    post feedbacks_path, params: params, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].present?
  end

  test "batch create responds with JSON when no ratings provided" do
    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {}
    }

    post feedbacks_path, params: params, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "No category or ratings provided", json["error"]
  end

  # === Create Action - Single Feedback (Edge Cases) ===
  # Note: The single feedback path has a bug - question_id is not in permitted params
  # so feedback_params[:question_id] is nil, making category_id nil too

  test "create with feedback param but no question_id shows error" do
    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      feedback: {
        average_score: "4",
        comments: "Test"
      }
    }

    post feedbacks_path, params: params

    # No question_id means it falls through to the else clause
    assert_response :unprocessable_entity
  end

  # === Create Action - Error Cases ===

  test "create without ratings or feedback params returns error" do
    params = {
      survey_id: @survey.id,
      student_id: @student.student_id
    }

    post feedbacks_path, params: params

    assert_response :unprocessable_entity
  end

  test "create without ratings or feedback responds with JSON error" do
    params = {
      survey_id: @survey.id,
      student_id: @student.student_id
    }

    post feedbacks_path, params: params, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "No category or ratings provided", json["error"]
  end

  # === Update Action ===

  test "update feedback successfully" do
    patch feedback_path(@feedback), params: {
      feedback: {
        average_score: "4.8",
        comments: "Updated comments"
      }
    }

    assert_redirected_to feedback_path(@feedback)
    @feedback.reload
    assert_equal 4.8, @feedback.average_score
    assert_equal "Updated comments", @feedback.comments
  end

  test "update feedback with survey and student context redirects to new feedback page" do
    patch feedback_path(@feedback), params: {
      feedback: {
        survey_id: @survey.id,
        student_id: @student.student_id,
        average_score: "4.5",
        comments: "Updated"
      }
    }

    assert_redirected_to new_feedback_path(survey_id: @survey.id, student_id: @student.student_id)
  end

  test "update feedback responds with JSON" do
    patch feedback_path(@feedback), params: {
      feedback: {
        average_score: "4.9"
      }
    }, as: :json

    assert_response :ok
  end

  test "update feedback with validation error" do
    patch feedback_path(@feedback), params: {
      feedback: {
        average_score: "invalid"
      }
    }

    assert_response :unprocessable_entity
  end

  test "update feedback with validation error responds with JSON" do
    patch feedback_path(@feedback), params: {
      feedback: {
        average_score: "invalid"
      }
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["average_score"].present?
  end

  # === Destroy Action ===

  test "destroy deletes feedback and redirects" do
    feedback = Feedback.create!(
      student_id: @student.student_id,
      survey_id: @survey.id,
      category_id: @cat1.id,
      advisor_id: @advisor.advisor_id,
      average_score: 3,
      comments: "To delete"
    )

    assert_difference "Feedback.count", -1 do
      delete feedback_path(feedback)
    end

    assert_redirected_to feedbacks_path
  end

  test "destroy responds with JSON" do
    feedback = Feedback.create!(
      student_id: @student.student_id,
      survey_id: @survey.id,
      category_id: @cat1.id,
      advisor_id: @advisor.advisor_id,
      average_score: 3,
      comments: "To delete"
    )

    assert_difference "Feedback.count", -1 do
      delete feedback_path(feedback), as: :json
    end

    assert_response :no_content
  end

  # === Edge Cases ===

  test "batch create with invalid question raises error due to null category_id" do
    invalid_question_id = 999999

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        invalid_question_id.to_s => { average_score: "4", comments: "Test" }
      }
    }

    post feedbacks_path, params: params
    assert_response :unprocessable_entity
  end

  test "new loads context properly" do
    # Just test it doesn't error and loads the view
    get new_feedback_path, params: { survey_id: @survey.id, student_id: @student.student_id }
    assert_response :success
  end

  test "create with existing feedback by id that doesn't match returns error" do
    q1 = @cat1.questions.first || @cat1.questions.create!(question_text: "Q1", question_order: 1, question_type: "short_answer")

    params = {
      survey_id: @survey.id,
      student_id: @student.student_id,
      ratings: {
        q1.id.to_s => { id: 999999, average_score: "4", comments: "Test" }
      }
    }

    post feedbacks_path, params: params

    assert_response :unprocessable_entity
  end
end
