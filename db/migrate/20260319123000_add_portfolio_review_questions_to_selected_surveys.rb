# frozen_string_literal: true

class AddPortfolioReviewQuestionsToSelectedSurveys < ActiveRecord::Migration[8.0]
  TARGET_SURVEY_TITLES = [
    "EMHA Final Competency Survey",
    "EMHA Mid-point Competency Survey",
    "RMHA Final Competency Survey"
  ].freeze

  SECTION_TITLE = "Portfolio Review"
  SECTION_DESCRIPTION = "Each student should review their portfolio, reflect on their experience/performance in the program, and then respond to the questions that follow."
  CATEGORY_NAME = "Portfolio Review"
  CATEGORY_DESCRIPTION = "Student reflection before advisor review meeting"
  EVIDENCE_SECTION_TITLE = "Evidence"

  QUESTION_TEXTS = [
    "Are you satisfied with where you are (competency [knowledge, skills, behaviors] development) at this time?",
    "What are you thinking (at this time) for career direction (location, type of organization, position/role, etc.)?",
    "What are you going to do to support your development and gain further career direction?",
    "What do you need from me to support your development?"
  ].freeze

  class Survey < ActiveRecord::Base
    self.table_name = "surveys"
  end

  class SurveySection < ActiveRecord::Base
    self.table_name = "survey_sections"
  end

  class Category < ActiveRecord::Base
    self.table_name = "categories"
  end

  class Question < ActiveRecord::Base
    self.table_name = "questions"
  end

  def up
    return unless table_exists?(:surveys)
    return unless table_exists?(:survey_sections)
    return unless table_exists?(:categories)
    return unless table_exists?(:questions)

    say_with_time "Adding portfolio review questions to selected competency surveys" do
      Survey.where(title: TARGET_SURVEY_TITLES).find_each do |survey|
        ensure_portfolio_review_for!(survey)
      end
    end
  end

  def down
    return unless table_exists?(:surveys)
    return unless table_exists?(:survey_sections)
    return unless table_exists?(:categories)
    return unless table_exists?(:questions)

    say_with_time "Removing portfolio review questions from selected competency surveys" do
      Survey.where(title: TARGET_SURVEY_TITLES).find_each do |survey|
        remove_portfolio_review_for!(survey)
      end
    end
  end

  private

  def ensure_portfolio_review_for!(survey)
    evidence_section = SurveySection.where(survey_id: survey.id)
                                   .where("LOWER(title) = ?", EVIDENCE_SECTION_TITLE.downcase)
                                   .order(:position, :id)
                                   .first

    target_position = if evidence_section
      evidence_section.position.to_i + 1
    else
      SurveySection.where(survey_id: survey.id).maximum(:position).to_i + 1
    end

    section = SurveySection.find_or_initialize_by(survey_id: survey.id, title: SECTION_TITLE)
    section.description = SECTION_DESCRIPTION

    if section.new_record?
      SurveySection.where(survey_id: survey.id).where("position >= ?", target_position).update_all("position = position + 1")
      section.position = target_position
    elsif section.position != target_position
      section.position = target_position
    end
    section.save!

    category = Category.find_or_initialize_by(survey_id: survey.id, name: CATEGORY_NAME)
    category.description = CATEGORY_DESCRIPTION
    category.survey_section_id = section.id if category.respond_to?(:survey_section_id=)
    category.save!

    QUESTION_TEXTS.each_with_index do |text, index|
      question = Question.find_or_initialize_by(category_id: category.id, question_text: text)
      question.question_order = index + 1
      question.question_type = "short_answer"
      question.is_required = false if question.respond_to?(:is_required=)
      question.has_evidence_field = false if question.respond_to?(:has_evidence_field=)
      question.answer_options = nil if question.respond_to?(:answer_options=)
      question.parent_question_id = nil if question.respond_to?(:parent_question_id=)
      question.sub_question_order = 0 if question.respond_to?(:sub_question_order=)
      question.save!
    end
  end

  def remove_portfolio_review_for!(survey)
    categories = Category.where(survey_id: survey.id, name: CATEGORY_NAME)
    category_ids = categories.pluck(:id)

    if category_ids.any?
      Question.where(category_id: category_ids, question_text: QUESTION_TEXTS).delete_all
      categories.each do |category|
        next if Question.where(category_id: category.id).exists?

        category.destroy!
      end
    end

    section = SurveySection.find_by(survey_id: survey.id, title: SECTION_TITLE)
    return unless section
    return if Category.where(survey_section_id: section.id).exists?

    section.destroy!
  end
end
