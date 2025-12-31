require "test_helper"

class Admin::SurveysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin)
    @advisor_user = users(:advisor)
    @student_user = users(:student)
    @survey = surveys(:fall_2025)
    sign_in @admin_user
  end

  # === Authentication & Authorization ===

  test "requires admin role for index" do
    sign_out @admin_user
    sign_in @advisor_user

    get admin_surveys_path
    assert_redirected_to dashboard_path
  end

  test "requires admin role for new" do
    sign_out @admin_user
    sign_in @student_user

    get new_admin_survey_path
    assert_redirected_to dashboard_path
  end

  test "requires admin role for create" do
    sign_out @admin_user
    sign_in @advisor_user

    assert_no_difference "Survey.count" do
      post admin_surveys_path, params: { survey: { title: "Test", semester: "Fall 2026" } }
    end
    assert_redirected_to dashboard_path
  end

  test "requires admin role for edit" do
    sign_out @admin_user
    sign_in @advisor_user

    get edit_admin_survey_path(@survey)
    assert_redirected_to dashboard_path
  end

  test "requires admin role for update" do
    sign_out @admin_user
    sign_in @advisor_user

    patch admin_survey_path(@survey), params: { survey: { title: "Changed" } }
    assert_redirected_to dashboard_path

    @survey.reload
    refute_equal "Changed", @survey.title
  end

  test "requires admin role for destroy" do
    sign_out @admin_user
    sign_in @advisor_user

    assert_no_difference "Survey.count" do
      delete admin_survey_path(@survey)
    end
    assert_redirected_to dashboard_path
  end

  test "requires admin role for archive" do
    sign_out @admin_user
    sign_in @advisor_user

    patch archive_admin_survey_path(@survey)
    assert_redirected_to dashboard_path

    @survey.reload
    assert @survey.is_active?
  end

  test "requires admin role for activate" do
    sign_out @admin_user
    sign_in @advisor_user

    @survey.update!(is_active: false)

    patch activate_admin_survey_path(@survey)
    assert_redirected_to dashboard_path

    @survey.reload
    refute @survey.is_active?
  end

  test "requires admin role for preview" do
    sign_out @admin_user
    sign_in @advisor_user

    get preview_admin_survey_path(@survey)
    assert_redirected_to dashboard_path
  end

  test "updating survey due date updates existing assignments and reconciles auto assignments" do
    assignment = survey_assignments(:residential_assignment)
    assert_equal @survey.id, assignment.survey_id

    new_due_date = 10.days.from_now.to_date

    assert_enqueued_with(job: ReconcileSurveyAssignmentsJob, args: [ { survey_id: @survey.id } ]) do
      patch admin_survey_path(@survey), params: { survey: { due_date: new_due_date.to_s } }
    end

    assert_redirected_to admin_surveys_path

    assignment.reload
    assert_equal new_due_date, assignment.due_date.to_date
  end

  test "warns when target levels change for surveys with submitted students" do
    completed_assignment = survey_assignments(:completed_residential_assignment)
    assert_equal @survey.id, completed_assignment.survey_id
    assert completed_assignment.completed_at?

    question = questions(:fall_q1)
    category = categories(:clinical_skills)
    assert_equal @survey.id, category.survey_id
    assert_equal category.id, question.category_id

    patch admin_survey_path(@survey), params: {
      survey: {
        categories_attributes: {
          "0" => {
            id: category.id,
            questions_attributes: {
              "0" => { id: question.id, program_target_level: "3" }
            }
          }
        }
      }
    }

    assert_redirected_to admin_surveys_path
    assert flash[:warning].present?
    assert_match(/Target levels changed/i, flash[:warning].to_s)
  end

  test "does not warn when target levels change but no one has submitted" do
    SurveyAssignment.where(survey_id: @survey.id).update_all(completed_at: nil)

    question = questions(:fall_q1)
    category = categories(:clinical_skills)

    patch admin_survey_path(@survey), params: {
      survey: {
        categories_attributes: {
          "0" => {
            id: category.id,
            questions_attributes: {
              "0" => { id: question.id, program_target_level: "4" }
            }
          }
        }
      }
    }

    assert_redirected_to admin_surveys_path
    assert flash[:warning].blank?
  end

  # === Index Action ===

  test "index displays surveys successfully" do
    get admin_surveys_path
    assert_response :success
  end

  test "index with search query" do
    get admin_surveys_path, params: { q: "Fall" }
    assert_response :success
  end

  test "index with track filter" do
    @survey.assign_tracks!([ "Residential" ])

    get admin_surveys_path, params: { track: "Residential" }
    assert_response :success
  end

  test "index with unassigned track filter" do
    @survey.assign_tracks!([])

    get admin_surveys_path, params: { track: "__unassigned" }
    assert_response :success
  end

  test "index with sort parameter" do
    get admin_surveys_path, params: { sort: "title", direction: "asc" }
    assert_response :success
  end

  test "index with invalid sort defaults gracefully" do
    get admin_surveys_path, params: { sort: "invalid_column" }
    assert_response :success
  end

  test "index with desc direction" do
    get admin_surveys_path, params: { direction: "desc" }
    assert_response :success
  end

  test "index sorts by question_count" do
    get admin_surveys_path, params: { sort: "question_count", direction: "desc" }
    assert_response :success
  end

  test "index sorts by category_count" do
    get admin_surveys_path, params: { sort: "category_count", direction: "asc" }
    assert_response :success
  end

  test "search handles special characters" do
    get admin_surveys_path, params: { q: "Fall & Spring" }
    assert_response :success
  end

  test "search is case insensitive" do
    get admin_surveys_path, params: { q: "FALL" }
    assert_response :success
  end

  test "search matches title, semester, and description" do
    @survey.update!(description: "Unique search term xyz123")

    get admin_surveys_path, params: { q: "xyz123" }
    assert_response :success
  end

  # === New Action ===

  test "new renders form successfully" do
    get new_admin_survey_path
    assert_response :success
  end

  test "new with current program semester" do
    ProgramSemester.find_by(current: true)&.update(name: "Spring 2027")

    get new_admin_survey_path
    assert_response :success
  end

  test "new with no current program semester falls back to calculated" do
    ProgramSemester.destroy_all

    get new_admin_survey_path
    assert_response :success
  end

  # === Create Action ===

  test "creates survey with tracks and logs change" do
    params = {
      survey: {
        title: "Capstone Survey",
        description: "Capstone overview",
        semester: "Fall 2026",
        is_active: true,
        track_list: [ "Residential" ],
        categories_attributes: {
          "0" => {
            name: "Leadership",
            description: "Leadership competencies",
            questions_attributes: {
              "0" => {
                question_text: "Describe your leadership style",
                question_type: "short_answer",
                question_order: 1,
                is_required: true,
                has_evidence_field: false,
                answer_options: ""
              }
            }
          }
        }
      }
    }

    assert_difference [ "Survey.count", "SurveyTrackAssignment.count", "SurveyChangeLog.count" ] do
      post admin_surveys_path, params: params
    end

    assert_redirected_to admin_surveys_path

    survey = Survey.order(:created_at).last
    assert_equal "Capstone Survey", survey.title
    assert_equal [ "Residential" ], survey.track_list
    assert_equal 1, survey.categories.count
    assert_equal 1, survey.questions.count

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "create", log.action
    assert_equal survey, log.survey
    assert_equal @admin_user, log.admin
    assert_equal "Survey created with 1 track(s)", log.description
  end

  test "create with multiple tracks" do
    params = {
      survey: {
        title: "Multi-track Survey",
        semester: "Fall 2026",
        track_list: [ "Residential", "Executive" ],
        categories_attributes: {
          "0" => {
            name: "Category",
            questions_attributes: {
              "0" => { question_text: "Q1", question_type: "short_answer", question_order: 1 }
            }
          }
        }
      }
    }

    assert_difference "Survey.count" do
      post admin_surveys_path, params: params
    end

    survey = Survey.order(:created_at).last
    assert_equal [ "Executive", "Residential" ], survey.track_list.sort
  end

  test "create sets creator to current admin" do
    params = {
      survey: {
        title: "Creator Test",
        semester: "Fall 2026",
        categories_attributes: {
          "0" => {
            name: "Cat",
            questions_attributes: {
              "0" => { question_text: "Q", question_type: "short_answer", question_order: 1 }
            }
          }
        }
      }
    }

    post admin_surveys_path, params: params

    survey = Survey.order(:created_at).last
    assert_equal @admin_user, survey.creator
  end

  test "create allows tooltip text" do
    params = {
      survey: {
        title: "Tooltip Survey",
        semester: "Fall 2026",
        categories_attributes: {
          "0" => {
            name: "Leadership",
            questions_attributes: {
              "0" => {
                question_text: "Describe a recent win",
                question_type: "short_answer",
                question_order: 1,
                tooltip_text: "Connect your answer to STAR outcomes."
              }
            }
          }
        }
      }
    }

    assert_difference "Survey.count", 1 do
      post admin_surveys_path, params: params
    end

    survey = Survey.order(:created_at).last
    tooltip = survey.questions.first.tooltip_text
    assert_equal "Connect your answer to STAR outcomes.", tooltip
  end

  test "create supports sections with category assignments" do
    section_uid = "section-temp-test"
    params = {
      survey: {
        title: "Sectioned Survey",
        semester: "Fall 2026",
        sections_attributes: {
          "0" => {
            title: "Student Experience",
            description: "Covers advising touchpoints",
            position: 0,
            form_uid: section_uid
          }
        },
        categories_attributes: {
          "0" => {
            name: "Touchpoints",
            description: "Advising interactions",
            section_form_uid: section_uid,
            questions_attributes: {
              "0" => {
                question_text: "List recent meetings",
                question_type: "short_answer",
                question_order: 1
              }
            }
          }
        }
      }
    }

    assert_difference [ "Survey.count", "SurveySection.count" ], 1 do
      post admin_surveys_path, params: params
    end

    survey = Survey.order(:created_at).last
    section = survey.sections.first
    category = survey.categories.first

    assert_equal "Student Experience", section.title
    assert_equal section, category.section
  end

  test "create with invalid params renders new with errors" do
    params = {
      survey: {
        title: "",
        semester: "Fall 2026"
      }
    }

    assert_no_difference "Survey.count" do
      post admin_surveys_path, params: params
    end

    assert_response :unprocessable_entity
  end

  test "create with nested categories and questions" do
    params = {
      survey: {
        title: "Nested Survey",
        semester: "Fall 2026",
        categories_attributes: {
          "0" => {
            name: "Cat1",
            questions_attributes: {
              "0" => { question_text: "Q1", question_type: "short_answer", question_order: 1 },
              "1" => { question_text: "Q2", question_type: "evidence", question_order: 2 }
            }
          },
          "1" => {
            name: "Cat2",
            questions_attributes: {
              "0" => { question_text: "Q3", question_type: "multiple_choice", question_order: 1, answer_options: "Yes\nNo" }
            }
          }
        }
      }
    }

    assert_difference "Survey.count" do
      post admin_surveys_path, params: params
    end

    survey = Survey.order(:created_at).last
    assert_equal 2, survey.categories.count
    assert_equal 3, survey.questions.count
  end

  test "create without categories fails validation" do
    params = {
      survey: {
        title: "No Categories",
        semester: "Fall 2026",
        categories_attributes: {}
      }
    }

    assert_no_difference "Survey.count" do
      post admin_surveys_path, params: params
    end

    assert_response :unprocessable_entity
  end

  # === Edit Action ===

  test "edit renders form successfully" do
    get edit_admin_survey_path(@survey)
    assert_response :success
  end

  test "edit with survey that has no categories builds default" do
    # Create survey with at least one category to pass validation
    survey = Survey.new(title: "Empty Survey", semester: "Fall 2026", creator: @admin_user)
    category = survey.categories.build(name: "Initial Category")
    category.questions.build(question_text: "Q", question_type: "short_answer", question_order: 1)
    survey.save!

    # Remove categories to test the build_default_structure behavior
    survey.categories.destroy_all

    get edit_admin_survey_path(survey)
    assert_response :success
  end

  # === Update Action ===

  test "updates survey and records change summary" do
    survey = surveys(:fall_2025)

    assert_difference "SurveyChangeLog.count" do
      patch admin_survey_path(survey), params: {
        survey: {
          title: "Updated Survey Title",
          description: "Updated details",
          track_list: [ "Executive" ]
        }
      }
    end

    assert_redirected_to admin_surveys_path

    survey.reload
    assert_equal "Updated Survey Title", survey.title
    assert_equal [ "Executive" ], survey.track_list

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "update", log.action
    assert_equal survey, log.survey
    assert_equal @admin_user, log.admin
    assert_includes log.description, "Tracks updated to Executive"
    assert_includes log.description, "Title changed from"
  end

  test "update with semester change" do
    assert_difference "SurveyChangeLog.count" do
      patch admin_survey_path(@survey), params: {
        survey: { semester: "Spring 2027" }
      }
    end

    @survey.reload
    assert_equal "Spring 2027", @survey.semester

    log = SurveyChangeLog.order(:created_at).last
    assert_includes log.description, "Semester changed from"
  end

  test "update allows reassigning categories to new sections" do
    category = @survey.categories.first
    existing_section = @survey.sections.create!(title: "Existing", description: "", position: 0)
    section_uid = "section-#{existing_section.id}"
    new_section_uid = "section-temp-xyz"

    patch admin_survey_path(@survey), params: {
      survey: {
        title: @survey.title,
        sections_attributes: {
          "0" => {
            id: existing_section.id,
            title: existing_section.title,
            description: existing_section.description,
            position: existing_section.position,
            form_uid: section_uid
          },
          "1" => {
            title: "Advisor Touchpoints",
            description: "",
            position: existing_section.position + 1,
            form_uid: new_section_uid
          }
        },
        categories_attributes: {
          "0" => {
            id: category.id,
            name: category.name,
            description: category.description,
            section_form_uid: new_section_uid
          }
        }
      }
    }

    assert_redirected_to admin_surveys_path

    category.reload
    assert_equal "Advisor Touchpoints", category.section.title
  end

  test "update allows editing tooltip text" do
    category = @survey.categories.first
    question = category.questions.first

    patch admin_survey_path(@survey), params: {
      survey: {
        categories_attributes: {
          "0" => {
            id: category.id,
            questions_attributes: {
              "0" => {
                id: question.id,
                tooltip_text: "Use concise bullet points"
              }
            }
          }
        }
      }
    }

    assert_redirected_to admin_surveys_path

    question.reload
    assert_equal "Use concise bullet points", question.tooltip_text
  end

  test "update with description change" do
    assert_difference "SurveyChangeLog.count" do
      patch admin_survey_path(@survey), params: {
        survey: { description: "New description text" }
      }
    end

    @survey.reload
    assert_equal "New description text", @survey.description

    log = SurveyChangeLog.order(:created_at).last
    assert_includes log.description, "Description changed from"
  end

  test "update with is_active change" do
    @survey.update!(is_active: true)

    assert_difference "SurveyChangeLog.count" do
      patch admin_survey_path(@survey), params: {
        survey: { is_active: false }
      }
    end

    @survey.reload
    refute @survey.is_active?

    log = SurveyChangeLog.order(:created_at).last
    assert_includes log.description, "Is active changed from"
  end

  test "update can add new category" do
    original_count = @survey.categories.count

    patch admin_survey_path(@survey), params: {
      survey: {
        categories_attributes: {
          "0" => {
            id: @survey.categories.first.id,
            name: @survey.categories.first.name
          },
          "1" => {
            name: "New Category",
            questions_attributes: {
              "0" => { question_text: "New Q", question_type: "short_answer", question_order: 1 }
            }
          }
        }
      }
    }

    @survey.reload
    assert_equal original_count + 1, @survey.categories.count
  end

  test "update can remove category" do
    category = @survey.categories.create!(name: "To Remove")
    category.questions.create!(question_text: "Q", question_type: "short_answer", question_order: 1)

    original_count = @survey.categories.count

    patch admin_survey_path(@survey), params: {
      survey: {
        categories_attributes: {
          "0" => {
            id: category.id,
            _destroy: "1"
          }
        }
      }
    }

    @survey.reload
    assert_equal original_count - 1, @survey.categories.count
  end

  test "update with invalid params renders edit with errors" do
    patch admin_survey_path(@survey), params: {
      survey: { title: "" }
    }

    assert_response :unprocessable_entity

    @survey.reload
    refute_equal "", @survey.title
  end

  # === Destroy Action ===

  test "destroy deletes survey and logs change" do
    survey = surveys(:spring_2025)

    # Logs change first, then destroys survey (change log remains via nullify)
    assert_difference "Survey.count", -1 do
      assert_difference "SurveyChangeLog.count", 1 do
        delete admin_survey_path(survey)
      end
    end

    assert_redirected_to admin_surveys_path

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "delete", log.action
    assert_includes log.description, "Spring 2025"
  end

  # === Archive Action ===

  test "archives survey and removes track assignments" do
    assert @survey.is_active?
    assert @survey.track_list.any?

    prior_assignment_count = SurveyTrackAssignment.count
    prior_tracks = @survey.track_list.size

    assert_difference "SurveyChangeLog.count" do
      patch archive_admin_survey_path(@survey)
    end

    assert_redirected_to admin_surveys_path

    @survey.reload
    refute @survey.is_active?
    assert_empty @survey.track_list
    assert_equal prior_assignment_count - prior_tracks, SurveyTrackAssignment.count
    assert_empty SurveyTrackAssignment.where(survey: @survey)

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "archive", log.action
    assert_equal @survey, log.survey
  end

  test "archive survey that is already archived" do
    @survey.update!(is_active: false)

    patch archive_admin_survey_path(@survey)

    assert_redirected_to admin_surveys_path
    @survey.reload
    refute @survey.is_active?
  end

  test "archive removes incomplete assignments but keeps completed records" do
    incomplete_assignment = survey_assignments(:residential_assignment)
    completed_assignment = survey_assignments(:completed_residential_assignment)
    question = questions(:fall_q1)

    assert_nil incomplete_assignment.completed_at
    assert_not_nil completed_assignment.completed_at
    assert StudentQuestion.exists?(student_id: incomplete_assignment.student_id, question_id: question.id)
    assert StudentQuestion.exists?(student_id: completed_assignment.student_id, question_id: question.id)

    patch archive_admin_survey_path(@survey)

    assert_redirected_to admin_surveys_path
    refute SurveyAssignment.exists?(incomplete_assignment.id)
    refute StudentQuestion.exists?(student_id: incomplete_assignment.student_id, question_id: question.id)
    assert SurveyAssignment.exists?(completed_assignment.id)
    assert StudentQuestion.exists?(student_id: completed_assignment.student_id, question_id: question.id)
  end

  # === Activate Action ===

  test "activates survey and logs change" do
    survey = surveys(:fall_2025)
    survey.update!(is_active: false)

    assert_difference "SurveyChangeLog.count" do
      patch activate_admin_survey_path(survey)
    end

    assert_redirected_to admin_surveys_path

    survey.reload
    assert survey.is_active?

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "activate", log.action
    assert_equal survey, log.survey
  end

  test "activate survey that is already active" do
    @survey.update!(is_active: true)

    patch activate_admin_survey_path(@survey)

    assert_redirected_to admin_surveys_path
    @survey.reload
    assert @survey.is_active?
  end

  # === Preview Action ===

  test "preview renders successfully and logs preview" do
    assert_difference "SurveyChangeLog.count" do
      get preview_admin_survey_path(@survey)
    end

    assert_response :success

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "preview", log.action
    assert_equal @survey, log.survey
  end

  test "preview with categories and questions" do
    get preview_admin_survey_path(@survey)
    assert_response :success
  end

  test "preview with required questions" do
    question = @survey.questions.first
    question.update!(is_required: true)

    get preview_admin_survey_path(@survey)
    assert_response :success
  end

  test "preview with multiple choice questions" do
    category = @survey.categories.first || @survey.categories.create!(name: "Test")
    category.questions.create!(
      question_text: "Choose one",
      question_type: "multiple_choice",
      answer_options: "Yes\nNo",
      question_order: 1,
      is_required: false
    )

    get preview_admin_survey_path(@survey)
    assert_response :success
  end

  test "preview with flexibility scale questions" do
    category = @survey.categories.first || @survey.categories.create!(name: "Test")
    category.questions.create!(
      question_text: "How flexible are you?",
      question_type: "multiple_choice",
      answer_options: "1\n2\n3\n4\n5",
      question_order: 1,
      is_required: false
    )

    get preview_admin_survey_path(@survey)
    assert_response :success
  end

  test "preview with track assignments" do
    @survey.assign_tracks!([ "Residential" ])

    get preview_admin_survey_path(@survey)
    assert_response :success
  end
end
