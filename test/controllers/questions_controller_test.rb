# frozen_string_literal: true

require "test_helper"

class QuestionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:admin)
    @question = questions(:fall_q1)
    @category = categories(:clinical_skills)
  end

  # INDEX action tests
  test "index displays all questions" do
    sign_in @admin

    get questions_path

    assert_response :success
    assert_includes @response.body, @question.question_text
  end

  test "index assigns all questions to @questions" do
    sign_in @admin

    get questions_path

    assert_response :success
    # Verify the page contains question content
    assert_not_nil @response.body
  end

  # SHOW action tests
  test "show displays a specific question" do
    sign_in @admin

    get question_path(@question)

    assert_response :success
    assert_includes @response.body, @question.question_text
  end

  test "show sets @question instance variable" do
    sign_in @admin

    get question_path(@question)

    assert_response :success
    assert_includes @response.body, @question.question_text
  end

  # NEW action tests
  test "new displays new question form" do
    sign_in @admin

    get new_question_path

    assert_response :success
    assert_includes @response.body, "New question"
  end

  test "new creates new Question instance" do
    sign_in @admin

    get new_question_path

    assert_response :success
  end

  # EDIT action tests
  test "edit displays edit form for existing question" do
    sign_in @admin

    get edit_question_path(@question)

    assert_response :success
    assert_includes @response.body, @question.question_text
  end

  test "edit sets @question to correct question" do
    sign_in @admin

    get edit_question_path(@question)

    assert_response :success
    assert_includes @response.body, @question.question_text
  end

  # CREATE action tests
  test "create with valid params creates new question" do
    sign_in @admin

    assert_difference("Question.count", 1) do
      post questions_path, params: {
        question: {
          category_id: @category.id,
          question_text: "New test question?",
          question_order: 2,
          question_type: "short_answer",
          is_required: true
        }
      }
    end

    assert_redirected_to question_path(Question.last)
    follow_redirect!
    assert_equal "Question was successfully created.", flash[:notice]
  end

  test "create with invalid params does not create question" do
    sign_in @admin

    assert_no_difference("Question.count") do
      post questions_path, params: {
        question: {
          category_id: @category.id,
          question_text: "", # Invalid: blank question_text
          question_order: 2,
          question_type: "short_answer"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create sets flash notice on success" do
    sign_in @admin

    post questions_path, params: {
      question: {
        category_id: @category.id,
        question_text: "Success test question?",
        question_order: 3,
        question_type: "multiple_choice",
        is_required: false
      }
    }

    assert_equal "Question was successfully created.", flash[:notice]
  end

  test "create renders new template on failure" do
    sign_in @admin

    post questions_path, params: {
      question: {
        category_id: @category.id,
        question_text: "", # Invalid
        question_order: 2,
        question_type: "short_answer"
      }
    }

    assert_response :unprocessable_entity
    assert_includes @response.body, "New question"
  end

  test "create redirects to question on HTML format success" do
    sign_in @admin

    post questions_path, params: {
      question: {
        category_id: @category.id,
        question_text: "Redirect test question?",
        question_order: 4,
        question_type: "scale",
        is_required: true
      }
    }

    assert_response :redirect
    assert_redirected_to question_path(Question.last)
  end

  test "create supports JSON format on failure" do
    sign_in @admin

    post questions_path, params: {
      question: {
        category_id: @category.id,
        question_text: "", # Invalid
        question_order: 2,
        question_type: "short_answer"
      }
    }, as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(@response.body)
    assert json_response.key?("question_text")
  end

  # UPDATE action tests
  test "update with valid params updates question" do
    sign_in @admin

    patch question_path(@question), params: {
      question: {
        question_text: "Updated question text?"
      }
    }

    assert_redirected_to question_path(@question)
    @question.reload
    assert_equal "Updated question text?", @question.question_text
  end

  test "update with invalid params does not update question" do
    sign_in @admin
    original_text = @question.question_text

    patch question_path(@question), params: {
      question: {
        question_text: "" # Invalid: blank
      }
    }

    assert_response :unprocessable_entity
    @question.reload
    assert_equal original_text, @question.question_text
  end

  test "update sets flash notice on success" do
    sign_in @admin

    patch question_path(@question), params: {
      question: {
        question_text: "Successfully updated question?"
      }
    }

    follow_redirect!
    assert_equal "Question was successfully updated.", flash[:notice]
  end

  test "update renders edit template on failure" do
    sign_in @admin

    patch question_path(@question), params: {
      question: {
        question_text: "" # Invalid
      }
    }

    assert_response :unprocessable_entity
  end

  test "update redirects to question on HTML format success" do
    sign_in @admin

    patch question_path(@question), params: {
      question: {
        question_text: "Redirect updated question?"
      }
    }

    assert_response :redirect
    assert_redirected_to question_path(@question)
  end

  test "update supports JSON format on failure" do
    sign_in @admin

    patch question_path(@question), params: {
      question: {
        question_text: "" # Invalid
      }
    }, as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(@response.body)
    assert json_response.key?("question_text")
  end

  # DESTROY action tests
  test "destroy deletes the question" do
    sign_in @admin

    assert_difference("Question.count", -1) do
      delete question_path(@question)
    end

    assert_redirected_to questions_path
  end

  test "destroy sets flash notice" do
    sign_in @admin

    delete question_path(@question)

    follow_redirect!
    assert_equal "Question was successfully destroyed.", flash[:notice]
  end

  test "destroy supports JSON format" do
    sign_in @admin

    delete question_path(@question), as: :json

    assert_response :no_content
  end

  # Strong parameters tests
  test "question_params permits all allowed attributes" do
    sign_in @admin

    post questions_path, params: {
      question: {
        category_id: @category.id,
        question_text: "Permitted params test?",
        question_order: 5,
        question_type: "evidence",
        description: "Test description",
        answer_options: '["Option 1", "Option 2"]',
        is_required: true,
        has_evidence_field: true
      }
    }

    created_question = Question.last
    assert_equal "Permitted params test?", created_question.question_text
    assert_equal "Test description", created_question.description
    assert_equal true, created_question.is_required
    assert_equal true, created_question.has_evidence_field
  end

  test "question_params filters unpermitted attributes" do
    sign_in @admin

    post questions_path, params: {
      question: {
        category_id: @category.id,
        question_text: "Filter test?",
        question_order: 6,
        question_type: "short_answer",
        created_at: 1.year.ago, # Should be filtered
        updated_at: 1.year.ago  # Should be filtered
      }
    }

    created_question = Question.last
    # created_at and updated_at should be recent, not 1 year ago
    assert created_question.created_at > 1.minute.ago
  end

  test "question_params supports legacy text parameter" do
    sign_in @admin

    post questions_path, params: {
      question: {
        category_id: @category.id,
        text: "Legacy text param?", # Old format
        question_order: 7,
        question_type: "short_answer"
      }
    }

    created_question = Question.last
    assert_equal "Legacy text param?", created_question.question_text
  end

  # Edge case tests
  test "create with multiple question types" do
    sign_in @admin

    [ "multiple_choice", "scale", "short_answer", "evidence" ].each_with_index do |qtype, index|
      assert_difference("Question.count", 1) do
        post questions_path, params: {
          question: {
            category_id: @category.id,
            question_text: "#{qtype} question?",
            question_order: 10 + index,
            question_type: qtype,
            is_required: false
          }
        }
      end
    end
  end

  test "update changes question_type" do
    sign_in @admin

    patch question_path(@question), params: {
      question: {
        question_type: "multiple_choice"
      }
    }

    @question.reload
    assert_equal "multiple_choice", @question.question_type
  end

  test "update changes is_required flag" do
    sign_in @admin
    original_required = @question.is_required

    patch question_path(@question), params: {
      question: {
        is_required: !original_required
      }
    }

    @question.reload
    assert_equal !original_required, @question.is_required
  end

  test "set_question finds correct question by id" do
    sign_in @admin

    get question_path(@question)

    assert_response :success
    assert_includes @response.body, @question.question_text
  end

  test "create with all optional fields" do
    sign_in @admin

    post questions_path, params: {
      question: {
        category_id: @category.id,
        question_text: "Full params question?",
        question_order: 20,
        question_type: "multiple_choice",
        description: "Detailed description here",
        answer_options: '["Yes", "No", "Maybe"]',
        is_required: false,
        has_evidence_field: true
      }
    }

    created_question = Question.last
    assert_equal "Full params question?", created_question.question_text
    assert_equal "Detailed description here", created_question.description
    assert_equal '["Yes", "No", "Maybe"]', created_question.answer_options
    assert_equal false, created_question.is_required
    assert_equal true, created_question.has_evidence_field
  end

  test "update preserves unchanged attributes" do
    sign_in @admin
    original_order = @question.question_order
    original_type = @question.question_type

    patch question_path(@question), params: {
      question: {
        question_text: "Only text changed"
      }
    }

    @question.reload
    assert_equal "Only text changed", @question.question_text
    assert_equal original_order, @question.question_order
    assert_equal original_type, @question.question_type
  end
end
