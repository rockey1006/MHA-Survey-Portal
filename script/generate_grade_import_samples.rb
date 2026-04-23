require "fileutils"
require "axlsx"

output_dir = Rails.root.join("local_import_samples", "folder_run_samples")
FileUtils.mkdir_p(output_dir)

sample_label = ENV.fetch("SAMPLE_LABEL", Time.current.strftime("%Y%m%d_%H%M%S"))

students = Student.joins(:user).where.not(uin: [ nil, "" ]).order(:id).limit(4)
raise "Need at least 4 students with UINs to generate sample imports." if students.size < 4

canvas_course_code = "PHPM-779-#{sample_label[-3, 3] || '910'}"
direct_course_code = "PHPM-780-#{sample_label[-3, 3] || '911'}"
canvas_sheet_name = canvas_course_code.tr("-", "_")
direct_sheet_name = direct_course_code.tr("-", "_")

canvas_file = output_dir.join("folder_run_canvas_sample_#{sample_label}.xlsx")
direct_file = output_dir.join("folder_run_direct_sample_#{sample_label}.xlsx")

canvas_headers = [
  "Student",
  "ID",
  "SIS User ID",
  "SIS Login ID",
  "Section",
  "Discussion Post 1",
  "Case Study Memo",
  "Team Presentation"
]

canvas_rows = students.each_with_index.map do |student, index|
  [
    student.user.name,
    9_000 + index,
    student.uin,
    student.uin,
    canvas_course_code,
    [94, 89, 96, 86][index],
    [91, 95, 92, 88][index],
    [47, 45, 49, 43][index]
  ]
end

mapping_headers = [
  "assignment_name",
  "competency_title",
  "score_basis",
  "min_grade",
  "max_grade",
  "competency_level",
  "course_code"
]

mapping_rows = [
  [ "Discussion Post 1", "Policy Analysis", "points", 90, 100, 5, canvas_course_code ],
  [ "Discussion Post 1", "Policy Analysis", "points", 80, 89.99, 4, canvas_course_code ],
  [ "Discussion Post 1", "Policy Analysis", "points", 70, 79.99, 3, canvas_course_code ],
  [ "Discussion Post 1", "Policy Analysis", "points", 60, 69.99, 2, canvas_course_code ],
  [ "Discussion Post 1", "Policy Analysis", "points", 0, 59.99, 1, canvas_course_code ],
  [ "Case Study Memo", "Problem Solving, Decision Making, and Critical Thinking", "points", 90, 100, 5, canvas_course_code ],
  [ "Case Study Memo", "Problem Solving, Decision Making, and Critical Thinking", "points", 80, 89.99, 4, canvas_course_code ],
  [ "Case Study Memo", "Problem Solving, Decision Making, and Critical Thinking", "points", 70, 79.99, 3, canvas_course_code ],
  [ "Case Study Memo", "Problem Solving, Decision Making, and Critical Thinking", "points", 60, 69.99, 2, canvas_course_code ],
  [ "Case Study Memo", "Problem Solving, Decision Making, and Critical Thinking", "points", 0, 59.99, 1, canvas_course_code ],
  [ "Team Presentation", "Team Building and Collaboration", "percent", 90, 100, 5, canvas_course_code ],
  [ "Team Presentation", "Team Building and Collaboration", "percent", 80, 89.99, 4, canvas_course_code ],
  [ "Team Presentation", "Team Building and Collaboration", "percent", 70, 79.99, 3, canvas_course_code ],
  [ "Team Presentation", "Team Building and Collaboration", "percent", 60, 69.99, 2, canvas_course_code ],
  [ "Team Presentation", "Team Building and Collaboration", "percent", 0, 59.99, 1, canvas_course_code ]
]

canvas_package = Axlsx::Package.new
canvas_package.workbook.add_worksheet(name: canvas_sheet_name) do |sheet|
  sheet.add_row canvas_headers
  sheet.add_row [ "Points Possible", nil, nil, nil, nil, 100, 100, 50 ]
  canvas_rows.each { |row| sheet.add_row row }
end

canvas_package.workbook.add_worksheet(name: "mapping") do |sheet|
  sheet.add_row mapping_headers
  mapping_rows.each { |row| sheet.add_row row }
end

canvas_package.serialize(canvas_file.to_s)

direct_headers = [
  "Student name",
  "Student ID",
  "Student SIS ID",
  "EMHA competencies > Delivery, Organization, and Financing of Health Services and Health Systems result",
  "EMHA competencies > Delivery, Organization, and Financing of Health Services and Health Systems mastery points",
  "EMHA competencies > Legal & Ethical Bases for Health Services and Health Systems result",
  "EMHA competencies > Legal & Ethical Bases for Health Services and Health Systems mastery points",
  "RMHA competencies > Organizational Dynamics result",
  "RMHA competencies > Organizational Dynamics mastery points",
  "HPMC competencies > Ignore Me result",
  "HPMC competencies > Ignore Me mastery points"
]

direct_rows = students.each_with_index.map do |student, index|
  [
    student.user.name,
    student.student_id,
    student.uin,
    [95, 90, 88, 84][index],
    [5, 5, 4, 4][index],
    [89, 86, 82, 78][index],
    [4, 4, 4, 3][index],
    [93, 87, 85, 80][index],
    [5, 4, 4, 4][index],
    [100, 100, 100, 100][index],
    [5, 5, 5, 5][index]
  ]
end

direct_package = Axlsx::Package.new
direct_package.workbook.add_worksheet(name: direct_sheet_name) do |sheet|
  sheet.add_row direct_headers
  direct_rows.each { |row| sheet.add_row row }
end

direct_package.serialize(direct_file.to_s)

puts "Created:"
puts canvas_file
puts direct_file
