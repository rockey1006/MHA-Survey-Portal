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
end
