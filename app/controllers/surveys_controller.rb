class SurveysController < ApplicationController
  before_action :set_survey, only: %i[ show edit update destroy submit ]

  # GET /surveys or /surveys.json
  def index
    @surveys = Survey.ordered
  end

  # GET /surveys/1 or /surveys/1.json
  def show
    @existing_answers = {}
    @computed_required = {}
    @category_groups = @survey.categories.includes(category_questions: :question).order(:id)
    @existing_evidence_by_category = Hash.new { |hash, key| hash[key] = [] }
    @existing_evidence_by_question = Hash.new { |hash, key| hash[key] = [] }

    student = current_student
    return unless student

    responses = StudentQuestion
                  .joins(question: :survey_questions)
                  .where(student_id: student.id, survey_questions: { survey_id: @survey.id })
                  .includes(question: { category_questions: :category })

    responses.each do |response|
      @existing_answers[response.question_id] = response.answer

      question = response.question
      next unless question&.question_type_evidence?

      @existing_evidence_by_question[question.id] << response
      question.categories.each do |category|
        @existing_evidence_by_category[category.id] << response
      end
    end

    @existing_evidence_by_category.each_value do |records|
      records.sort_by! { |record| record.updated_at || record.created_at || Time.at(0) }
      records.reverse!
    end

    @existing_evidence_by_question.each_value do |records|
      records.sort_by! { |record| record.updated_at || record.created_at || Time.at(0) }
      records.reverse!
    end

    @category_groups.each do |category|
      category.category_questions.includes(:question).each do |category_question|
        question = category_question.question
        next unless question

        required = question.required?

        if question.question_type_evidence?
          @computed_required[question.id] = false
          next
        end

        if !required && question.question_type_multiple_choice?
          options = question.answer_options_list.map(&:strip).map(&:downcase)
          required = !(options == %w[yes no] || options == %w[no yes])
        end

        @computed_required[question.id] = required
      end
    end
  end

  # GET /surveys/new
  def new
    @survey = Survey.new
  end

  # GET /surveys/1/edit
  def edit
  end

  # POST /surveys or /surveys.json
  def create
    @survey = Survey.new(survey_params)

    respond_to do |format|
      if @survey.save
        format.html { redirect_to @survey, notice: "Survey was successfully created." }
        format.json { render :show, status: :created, location: @survey }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @survey.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /surveys/1 or /surveys/1.json
  def update
    respond_to do |format|
      if @survey.update(survey_params)
        format.html { redirect_to @survey, notice: "Survey was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @survey }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @survey.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /surveys/1 or /surveys/1.json
  def destroy
    @survey.destroy!

    respond_to do |format|
      format.html { redirect_to surveys_path, notice: "Survey was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end
  def submit
    student = current_student

    unless student
      redirect_to student_dashboard_path, alert: "Student record not found for current user."
      return
    end

    answers = params[:answers] || {}
    category_evidence_params = params[:category_evidence] || params[:evidence_links_by_category] || {}
    allowed_question_ids = @survey.questions.pluck(:id)

    category_evidence_params.each do |category_id_str, link_value|
      category = @survey.categories.find_by(id: category_id_str)
      next unless category

      question = find_category_evidence_question(category)
      normalized_link_value = link_value.to_s.strip

      if normalized_link_value.present?
        question ||= ensure_category_evidence_question(category)
        question_key = question.id.to_s
        answers[question_key] = normalized_link_value
        allowed_question_ids << question.id unless allowed_question_ids.include?(question.id)
      elsif question
        question_key = question.id.to_s
        answers[question_key] = ""
        allowed_question_ids << question.id unless allowed_question_ids.include?(question.id)
      end
    end

    missing_required = []
    invalid_links = []

    @survey.categories.includes(category_questions: :question).each do |category|
      category.category_questions.each do |category_question|
        question = category_question.question
        next unless question && allowed_question_ids.include?(question.id)

        required = question.required?
        if !required && question.question_type_multiple_choice?
          options = question.answer_options_list.map(&:strip).map(&:downcase)
          required = !(options == %w[yes no] || options == %w[no yes])
        end

        submitted_value = answers[question.id.to_s]

        if required && submitted_value.blank?
          missing_required << question
        end

        if question.question_type_evidence? && submitted_value.present?
          value_str = submitted_value.is_a?(String) ? submitted_value : submitted_value.to_s
          invalid_links << question unless value_str =~ StudentQuestion::DRIVE_URL_REGEX
        end
      end
    end

    if missing_required.any?
      flash[:alert] = "Please answer all required questions (marked with *)."
      flash[:missing_required_ids] = missing_required.map(&:id)
      redirect_to survey_path(@survey) and return
    end

    if invalid_links.any?
      names = invalid_links.map { |q| "Question #{q.question_order}: #{q.question}" }
      redirect_to survey_path(@survey), alert: "One or more evidence links are invalid: #{names.join('; ')}"
      return
    end

    ActiveRecord::Base.transaction do
      answers.each do |question_id_str, answer_value|
        next unless question_id_str.to_s.match?(/^\d+$/)
        question_id = question_id_str.to_i
        next unless allowed_question_ids.include?(question_id)

        record = StudentQuestion.find_or_initialize_by(student_id: student.id, question_id: question_id)
        record.advisor_id ||= student.advisor_id

        should_keep_record = answer_value.present?

        unless should_keep_record
          record.destroy! if record.persisted?
          next
        end

        record.answer = answer_value.presence
        record.save!
      end
    end

    survey_response_id = SurveyResponse.build(student: student, survey: @survey).id
    redirect_to survey_response_path(survey_response_id), notice: "Survey submitted successfully!"
  end
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_survey
      @survey = Survey.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def survey_params
      params.require(:survey).permit(:title, :semester)
    end

    def find_category_evidence_question(category)
      category.category_questions.includes(:question).map(&:question).compact.find(&:question_type_evidence?)
    end

    def ensure_category_evidence_question(category)
      @category_evidence_question_cache ||= {}
      return @category_evidence_question_cache[category.id] if @category_evidence_question_cache.key?(category.id)

      question = find_category_evidence_question(category)
      return @category_evidence_question_cache[category.id] = question if question

      next_order = (@survey.questions.maximum(:question_order) || 0) + 1
      question = Question.create!(
        question: "Evidence for #{category.name}",
        question_order: next_order,
        question_type: Question.question_types[:evidence],
        required: false
      )

      CategoryQuestion.create!(category: category, question: question, display_label: "Evidence for #{category.name}")
      SurveyQuestion.find_or_create_by!(survey: @survey, question: question)

      Student.find_each do |student_record|
        StudentQuestion.find_or_create_by!(student_id: student_record.student_id, question_id: question.id) do |record|
          record.advisor_id = student_record.advisor_id
        end
      end

      @category_evidence_question_cache[category.id] = question
    end
end
