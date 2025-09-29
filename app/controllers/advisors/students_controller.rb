module Advisors
  class StudentsController < ApplicationController
    def index
      # 获取所有学生和他们的 survey responses
      @students = Student.all.includes(:survey_responses)
    end
  end
end
