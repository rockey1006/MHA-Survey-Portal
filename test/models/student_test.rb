require "test_helper"

class StudentTest < ActiveSupport::TestCase
  test "delegates name to user" do
    student = students(:student)
    assert_equal "Student User", student.name
  end

  test "requires unique uin" do
    duplicate = Student.new(student_id: 99, advisor: advisors(:advisor), uin: "123456789", track: "Residential")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uin], "has already been taken"
  end

    test "uin must be exactly 9 digits" do
      student = students(:student)
      student.major = "Public Health"
      student.track = "Clinical"

      student.uin = "123"
      assert_not student.valid?(:profile_completion)
      assert_includes student.errors[:uin], "must be exactly 9 digits"

      student.uin = "1234567890"
      assert_not student.valid?(:profile_completion)
      assert_includes student.errors[:uin], "must be exactly 9 digits"
    end

    test "uin normalizes to digits" do
      student = students(:student)
      student.major = "Public Health"
      student.track = "Clinical"

      student.uin = "123-456-789"
      assert student.valid?(:profile_completion)
      assert_equal "123456789", student.uin
    end
end
