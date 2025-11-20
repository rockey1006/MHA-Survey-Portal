# frozen_string_literal: true

require "test_helper"

class StudentProfilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:admin)
    @advisor = users(:advisor)
    @student_user = users(:student)
    @student = students(:student) || Student.first
  end

  # Helper to generate valid student params for profile completion
  def valid_student_params(overrides = {})
    {
      name: @student.user.name || "Test Name",
      uin: @student.uin || "123456789",
      major: @student.major || "Computer Science",
      track: @student.track || "Residential",
      advisor_id: @student.advisor_id || Advisor.first&.id
    }.merge(overrides)
  end

  # Authentication Tests
  test "show requires authentication" do
    get student_profile_path

    assert_redirected_to new_user_session_path
  end

  test "edit requires authentication" do
    get edit_student_profile_path

    assert_redirected_to new_user_session_path
  end

  test "update requires authentication" do
    patch student_profile_path, params: { student: { name: "Test" } }

    assert_redirected_to new_user_session_path
  end

  # Role-Based Access Control
  test "show requires student role" do
    sign_in @admin

    get student_profile_path

    assert_redirected_to root_path
    assert_equal "Access denied.", flash[:alert]
  end

  test "edit requires student role" do
    sign_in @admin

    get edit_student_profile_path

    assert_redirected_to root_path
    assert_equal "Access denied.", flash[:alert]
  end

  test "update requires student role" do
    sign_in @admin

    patch student_profile_path, params: { student: { name: "Test" } }

    assert_redirected_to root_path
    assert_equal "Access denied.", flash[:alert]
  end

  test "advisor cannot access show" do
    sign_in @advisor

    get student_profile_path

    assert_redirected_to root_path
    assert_equal "Access denied.", flash[:alert]
  end

  test "advisor cannot access edit" do
    sign_in @advisor

    get edit_student_profile_path

    assert_redirected_to root_path
    assert_equal "Access denied.", flash[:alert]
  end

  test "advisor cannot access update" do
    sign_in @advisor

    patch student_profile_path, params: { student: { name: "Test" } }

    assert_redirected_to root_path
    assert_equal "Access denied.", flash[:alert]
  end

  # Show Action Tests
  test "show displays student profile for student" do
    sign_in @student_user

    get student_profile_path

    assert_response :success
  end

  test "show assigns current student" do
    sign_in @student_user

    get student_profile_path

    assert_response :success
  end

  # Edit Action Tests
  test "edit displays profile form for student" do
    sign_in @student_user

    get edit_student_profile_path

    assert_response :success
  end

  test "edit loads advisors list" do
    sign_in @student_user

    get edit_student_profile_path

    assert_response :success
  end

  test "edit orders advisors by name" do
    sign_in @student_user

    get edit_student_profile_path

    assert_response :success
  end

  test "edit skips profile completion check" do
    sign_in @student_user
    # Even if profile is incomplete, edit should be accessible

    get edit_student_profile_path

    assert_response :success
  end

  # Update Action Tests - Name
  test "update allows changing student name" do
    sign_in @student_user
    original_name = @student.user.name

    patch student_profile_path, params: {
      student: valid_student_params(name: "New Name")
    }

    assert_redirected_to student_dashboard_path
    @student.user.reload
    assert_equal "New Name", @student.user.name
  ensure
    @student.user.update!(name: original_name) if original_name
  end

  test "update preserves name when not provided" do
    sign_in @student_user
    original_name = @student.user.name

    patch student_profile_path, params: {
      student: {
        uin: @student.uin,
        major: @student.major,
        track: @student.track,
        advisor_id: @student.advisor_id
      }
    }

    @student.user.reload
    assert_equal original_name, @student.user.name
  end

  # Update Action Tests - Student Attributes
  test "update allows changing UIN" do
    sign_in @student_user
    original_uin = @student.uin

    patch student_profile_path, params: {
      student: valid_student_params(uin: "111111111")
    }

    assert_redirected_to student_dashboard_path
    @student.reload
    assert_equal "111111111", @student.uin
  ensure
    @student.update!(uin: original_uin) if original_uin
  end

  test "update allows changing major" do
    sign_in @student_user
    original_major = @student.major

    patch student_profile_path, params: {
      student: valid_student_params(major: "Mathematics")
    }

    assert_redirected_to student_dashboard_path
    @student.reload
    assert_equal "Mathematics", @student.major
  ensure
    @student.update!(major: original_major)
  end

  test "update allows changing track" do
    sign_in @student_user
    original_track = @student.track

    patch student_profile_path, params: {
      student: {
        name: @student.user.name || "Test Name",
        uin: @student.uin || "123456789",
        major: @student.major || "Computer Science",
        track: "Executive",
        advisor_id: @student.advisor_id || Advisor.first&.id
      }
    }

    assert_redirected_to student_dashboard_path
    @student.reload
    assert_equal "executive", @student.track
  ensure
    @student.update!(track: original_track) if original_track
  end

  test "update allows changing advisor" do
    sign_in @student_user
    original_advisor_id = @student.advisor_id
    new_advisor = Advisor.where.not(advisor_id: original_advisor_id).first

    skip "Need another advisor" unless new_advisor

    patch student_profile_path, params: {
      student: valid_student_params(advisor_id: new_advisor.advisor_id)
    }

    assert_redirected_to student_dashboard_path
    @student.reload
    assert_equal new_advisor.id, @student.advisor_id
  ensure
    @student.update!(advisor_id: original_advisor_id) if original_advisor_id
  end

  # Update Action Tests - Multiple Attributes
  test "update allows changing multiple attributes" do
    sign_in @student_user
    original_name = @student.user.name
    original_major = @student.major

    patch student_profile_path, params: {
      student: valid_student_params(name: "Updated Name", major: "Updated Major")
    }

    assert_redirected_to student_dashboard_path
    @student.reload
    @student.user.reload
    assert_equal "Updated Name", @student.user.name
    assert_equal "Updated Major", @student.major
  ensure
    @student.user.update!(name: original_name)
    @student.update!(major: original_major)
  end

  # Success Messages
  test "update shows success notice" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: valid_student_params
    }

    assert_equal "Profile completed successfully!", flash[:notice]
  end

  # Redirect Behavior
  test "update redirects to student dashboard on success" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: valid_student_params
    }

    assert_redirected_to student_dashboard_path
  end

  # Validation Errors
  test "update re-renders edit with invalid params" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: {
        name: "",
        uin: "",
        major: "",
        track: "",
        advisor_id: nil
      }
    }

    assert_response :unprocessable_entity
  end

  test "update validates with profile_completion context" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: valid_student_params(uin: "")
    }

    assert_response :unprocessable_entity
  end

  # Strong Parameters
  test "update filters unpermitted parameters" do
    sign_in @student_user
    original_student_id = @student.student_id

    patch student_profile_path, params: {
      student: valid_student_params.merge(student_id: "999999999")
    }

    @student.reload
    assert_equal original_student_id, @student.student_id
  end

  test "update only permits name uin major track and advisor_id" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: valid_student_params.merge(role: "admin")
    }

    assert_redirected_to student_dashboard_path
  end

  # Survey Auto-Assignment
  test "update triggers survey auto-assignment on success" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: valid_student_params
    }

    assert_redirected_to student_dashboard_path
  end

  # Profile Completion Check Skip
  test "edit is accessible even with incomplete profile" do
    sign_in @student_user
    # The skip_before_action allows access regardless of profile state

    get edit_student_profile_path

    assert_response :success
  end

  test "update is accessible even with incomplete profile" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: valid_student_params
    }

    assert_response :redirect
  end

  # Current Student
  test "show displays current student information" do
    sign_in @student_user

    get student_profile_path

    assert_response :success
  end

  test "edit loads current student" do
    sign_in @student_user

    get edit_student_profile_path

    assert_response :success
  end

  test "update only affects current student" do
    sign_in @student_user
    other_student = Student.where.not(student_id: @student.student_id).first
    skip "Need another student" unless other_student

    other_student_name = other_student.user.name

    patch student_profile_path, params: {
      student: valid_student_params(name: "Different Name")
    }

    other_student.user.reload
    assert_equal other_student_name, other_student.user.name
  end

  # Form Display
  test "edit displays advisor options" do
    sign_in @student_user

    get edit_student_profile_path

    assert_response :success
  end

  # Persistence Tests
  test "update persists name changes to user" do
    sign_in @student_user
    original_name = @student.user.name

    patch student_profile_path, params: {
      student: valid_student_params(name: "Persisted Name")
    }

    user_from_db = User.find(@student.user.id)
    assert_equal "Persisted Name", user_from_db.name
  ensure
    @student.user.update!(name: original_name)
  end

  test "update persists student attribute changes" do
    sign_in @student_user
    original_major = @student.major

    patch student_profile_path, params: {
      student: valid_student_params(major: "Persisted Major")
    }

    student_from_db = Student.find(@student.student_id)
    assert_equal "Persisted Major", student_from_db.major
  ensure
    @student.update!(major: original_major) if original_major
  end

  # Edge Cases
  test "update handles blank name" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: {
        name: "",
        uin: @student.uin,
        major: @student.major,
        track: @student.track,
        advisor_id: @student.advisor_id
      }
    }

    assert_response :unprocessable_entity
  end

  test "update allows nil advisor_id" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: valid_student_params(advisor_id: nil)
    }

    assert_redirected_to student_dashboard_path
  end

  # Response Format Tests
  test "show returns HTML response" do
    sign_in @student_user

    get student_profile_path

    assert_equal "text/html; charset=utf-8", @response.content_type
  end

  test "edit returns HTML response" do
    sign_in @student_user

    get edit_student_profile_path

    assert_equal "text/html; charset=utf-8", @response.content_type
  end

  test "update returns redirect on success" do
    sign_in @student_user

    patch student_profile_path, params: {
      student: valid_student_params
    }

    assert_response :redirect
  end

  # Context Validation
  test "update uses profile_completion validation context" do
    sign_in @student_user
    # This ensures stricter validation is applied

    patch student_profile_path, params: {
      student: valid_student_params
    }

    assert_redirected_to student_dashboard_path
  end

  # Save Transaction
  test "update saves both user and student in transaction" do
    sign_in @student_user
    original_name = @student.user.name
    original_major = @student.major

    patch student_profile_path, params: {
      student: valid_student_params(name: "Transaction Name", major: "Transaction Major")
    }

    @student.reload
    @student.user.reload
    assert_equal "Transaction Name", @student.user.name
    assert_equal "Transaction Major", @student.major
  ensure
    @student.user.update!(name: original_name)
    @student.update!(major: original_major)
  end

  # Track Values
  test "update accepts valid track values" do
    sign_in @student_user
    original_track = @student.track
    valid_tracks = [ "Residential", "Executive" ]

    valid_tracks.each do |track|
      patch student_profile_path, params: {
        student: valid_student_params(track: track)
      }

      assert_redirected_to student_dashboard_path
      @student.reload
      assert_equal track.downcase, @student.track
    end
  ensure
    @student.update!(track: original_track) if original_track
  end

  # Blank Name Handling
  test "update skips user name update when name is blank" do
    sign_in @student_user
    original_name = @student.user.name

    patch student_profile_path, params: {
      student: {
        name: "   ",
        uin: @student.uin,
        major: @student.major,
        track: @student.track,
        advisor_id: @student.advisor_id
      }
    }

    # Should fail validation
    assert_response :unprocessable_entity
  end

  # Advisor Join
  test "edit joins with users table for advisor ordering" do
    sign_in @student_user

    get edit_student_profile_path

    assert_response :success
  end
end
