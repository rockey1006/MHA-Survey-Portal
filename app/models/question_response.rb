# Decorator-style model exposing student question responses through the
# `SurveyResponse` association layer.
class QuestionResponse < StudentQuestion
  self.table_name = "student_questions"

  # @return [Survey, nil] the first survey associated with this response
  def survey
    question&.category&.survey
  end
end
