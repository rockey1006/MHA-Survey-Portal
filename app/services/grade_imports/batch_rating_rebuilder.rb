module GradeImports
  class BatchRatingRebuilder
    def self.call(batch:)
      new(batch: batch).call
    end

    def initialize(batch:)
      @batch = batch
    end

    def call
      batch.grade_competency_ratings.delete_all

      rows = batch.grade_competency_evidences
                  .group(:student_id, :competency_title)
                  .pluck(
                    :student_id,
                    :competency_title,
                    Arel.sql("MAX(mapped_level)"),
                    Arel.sql("COUNT(*)")
                  )

      return if rows.empty?

      timestamp = Time.current
      payload = rows.map do |student_id, competency_title, max_level, count|
        {
          grade_import_batch_id: batch.id,
          student_id: student_id,
          competency_title: competency_title,
          aggregated_level: max_level,
          aggregation_rule: "max",
          evidence_count: count,
          created_at: timestamp,
          updated_at: timestamp
        }
      end

      GradeCompetencyRating.insert_all(payload)
    end

    private

    attr_reader :batch
  end
end
