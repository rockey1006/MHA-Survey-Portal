module Advisors
  class StudentsController < ApplicationController
    MOCK_STUDENTS = [
  { id: 1, first_name: "Alice",  last_name: "Nguyen", email: "alice@example.edu" },
  { id: 2, first_name: "Brian",  last_name: "Smith",  email: "brian@example.edu" },
  { id: 3, first_name: "Cara",   last_name: "Lee",    email: "cara@example.edu"  },
  { id: 4, first_name: "Diego",  last_name: "Martín", email: "diego@example.edu" }
].freeze


    def index
      @students = MOCK_STUDENTS
    end
  end
end
