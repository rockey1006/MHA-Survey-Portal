module GradeImports
  class DerivedScorebook
    def self.for_student(student)
      new(student_ids: [ student.student_id ]).by_student.fetch(student.student_id, {})
    end

    def self.for_students(student_ids)
      new(student_ids: student_ids).by_student
    end

    def initialize(student_ids:)
      @student_ids = Array(student_ids).compact.uniq
    end

    def by_student
      return {} if student_ids.empty?

      evidence_scope
        .group_by(&:student_id)
        .transform_values do |student_rows|
          student_rows.group_by(&:competency_title).transform_values do |competency_rows|
            latest = competency_rows.max_by(&:updated_at)

            {
              aggregated_level: competency_rows.map(&:mapped_level).max,
              evidence_count: competency_rows.size,
              latest_updated_at: latest&.updated_at,
              provenance: competency_rows
                          .sort_by { |row| [ row.course_code.to_s, row.assignment_name.to_s, row.updated_at.to_i ] }
                          .map do |row|
                {
                  course_code: row.course_code,
                  assignment_name: row.assignment_name,
                  mapped_level: row.mapped_level,
                  course_target_level: row.course_target_level,
                  raw_grade: row.raw_grade,
                  updated_at: row.updated_at,
                  import_file: row.grade_import_file&.file_name
                }
              end
            }
          end
        end
    end

    private

    attr_reader :student_ids

    def evidence_scope
      GradeCompetencyEvidence
        .includes(:grade_import_file)
        .joins(:grade_import_batch)
        .merge(GradeImportBatch.reportable)
        .where(student_id: student_ids)
        .order(:student_id, :competency_title, :updated_at)
    end
  end
end
