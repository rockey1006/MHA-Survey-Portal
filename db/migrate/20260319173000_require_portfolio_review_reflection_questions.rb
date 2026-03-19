class RequirePortfolioReviewReflectionQuestions < ActiveRecord::Migration[8.0]
  QUESTION_TEXTS = [
    "Are you satisfied with where you are (competency [knowledge, skills, behaviors] development) at this time?",
    "What are you thinking (at this time) for career direction (location, type of organization, position/role, etc.)?",
    "What are you going to do to support your development and gain further career direction?",
    "What do you need from me to support your development?"
  ].freeze

  def up
    return unless table_exists?(:questions)

    migration_question = Class.new(ActiveRecord::Base) do
      self.table_name = "questions"
    end

    migration_question.where(question_text: QUESTION_TEXTS).update_all(is_required: true, updated_at: Time.current)
  end

  def down; end
end
