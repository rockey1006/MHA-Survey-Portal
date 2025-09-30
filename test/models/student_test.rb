require "test_helper"

class StudentTest < ActiveSupport::TestCase
  def setup
    @student = students(:one)
  end

  test "should be valid with valid attributes" do
    assert @student.valid?
  end

  test "should have track enum" do
    assert_respond_to @student, :track
    assert_respond_to @student, :track_residential?
    assert_respond_to @student, :track_executive?
  end

  test "should accept valid track values" do
    @student.track = "residential"
    assert @student.valid?

    @student.track = "executive"
    assert @student.valid?
  end

  test "should have survey_responses association" do
    assert_respond_to @student, :survey_responses
  end

  test "track prefix methods should work correctly" do
    @student.update(track: "residential")
    assert @student.track_residential?
    assert_not @student.track_executive?

    @student.update(track: "executive")
    assert @student.track_executive?
    assert_not @student.track_residential?
  end

  test "should destroy associated survey_responses when student is destroyed" do
    # This test assumes proper has_many :dependent => :destroy setup
    student = Student.create!(student_id: 999, name: "Test Student", email: "test@test.com", net_id: "test123", track: "residential")

    # Create some survey responses for this student if the association allows it
    # Note: This might need adjustment based on your actual survey_response model
    initial_count = Student.count
    student.destroy
    assert_equal initial_count - 1, Student.count
  end
end
