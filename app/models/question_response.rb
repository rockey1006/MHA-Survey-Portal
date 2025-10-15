class QuestionResponse < StudentQuestion
  self.table_name = "student_questions"

  def survey
    surveys.first
  end
end
