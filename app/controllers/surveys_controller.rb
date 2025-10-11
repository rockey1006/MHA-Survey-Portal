class SurveysController < ApplicationController
  before_action :set_survey, only: %i[ show edit update destroy submit ]

  # GET /surveys or /surveys.json
  def index
    # Show all surveys to the user on the index page
    @surveys = Survey.all.order(:id)
  end

  # GET /surveys/1 or /surveys/1.json
  def show
    # If a student is signed in (via current_admin), collect existing answers so the
    # survey form can pre-fill previously submitted responses for editing/resubmission.
    @existing_answers = {}
    if defined?(current_admin) && current_admin.present?
      student = Student.find_by(email: current_admin.email)
      if student
        # Find the survey_response for this student & survey
        sr = SurveyResponse.find_by(student_id: student.id, survey_id: @survey.id)
        if sr
          # Collect question responses only for this survey_response
          qrs = QuestionResponse.where(surveyresponse_id: sr.id)
          qrs.each do |qr|
            @existing_answers[qr.question_id] = qr.answer
          end

          # For evidence-type questions, previous submissions are read from QuestionResponse.answer
          @existing_evidence_by_category = {}
          @existing_evidence_by_question = {}
          # collect all question_responses for this survey_response and group them
          qrs = QuestionResponse.where(surveyresponse_id: sr.id).includes(:question)
          qrs.each do |qr|
            q = qr.question
            next unless q && q.question_type == "evidence"
            cid = q.category_id
            @existing_evidence_by_category[cid] ||= []
            @existing_evidence_by_category[cid] << qr
            @existing_evidence_by_question[qr.question_id] ||= []
            @existing_evidence_by_question[qr.question_id] << qr
          end
          # sort entries by created_at desc
          @existing_evidence_by_category.each { |k, arr| arr.sort_by! { |x| x.created_at || Time.at(0) }.reverse! }
          @existing_evidence_by_question.each { |k, arr| arr.sort_by! { |x| x.created_at || Time.at(0) }.reverse! }
          # Pre-compute which questions should be marked required in the UI so view logic is simple
          @computed_required = {}
          @survey.categories.includes(:questions).each do |cat2|
            cat2.questions.each do |qq|
              # If the question has a dependency, it's required only when the dependency is satisfied
              if qq.depends_on_question_id.present?
                dep_qid = qq.depends_on_question_id.to_i
                dep_expected = qq.depends_on_value.to_s
                dep_actual = @existing_answers[dep_qid]
                @computed_required[qq.id] = (dep_actual.to_s == dep_expected)
                next
              end

              is_required = qq.required
              # Default rule for non-conditional questions
              if !is_required
                case qq.question_type
                when "multiple_choice"
                  raw_opts = (qq.answer_options || "").to_s
                  parsed = begin
                    JSON.parse(raw_opts) rescue nil
                  end
                  options = if parsed.is_a?(Array)
                              parsed.map(&:to_s)
                  else
                              raw_opts.gsub(/[\[\]"“”]/, "").split(",").map(&:strip).reject(&:empty?)
                  end
                  normalized = options.map { |o| o.to_s.strip.downcase }
                  # Yes/No multiple choice are NOT required by default
                  is_required = !(normalized == [ "yes", "no" ] || normalized == [ "no", "yes" ])
                else
                  is_required = true
                end
              end
              @computed_required[qq.id] = is_required
            end
          end
        end
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
  # POST /surveys/1/submit
  def submit
    # identify the acting student: try to match current_admin (Devise) to Student by email
    student = nil
    if defined?(current_admin) && current_admin.present?
      student = Student.find_by(email: current_admin.email)
    elsif defined?(current_user) && current_user.present?
      # tests sign in a User fixture; get the associated Student profile
      # User has_one :student_profile (Student) via student_profile
      student = current_user.student_profile
    end

    unless student
      redirect_to student_dashboard_path, alert: "Student record not found for current user."
      return
    end

  # Find or create survey_response and mark submitted
  survey_response = SurveyResponse.find_or_initialize_by(student_id: student.id, survey_id: @survey.id)
  survey_response.status = SurveyResponse.statuses[:submitted]
  survey_response.advisor_id ||= student.advisor_id
  # Some schemas may not have a semester column on SurveyResponse; only set if present
  if survey_response.respond_to?(:semester)
    survey_response.semester ||= params[:semester]
  end
  survey_response.save!

  # Validate and save answers
  answers = params[:answers] || {}
  # Support both legacy per-question evidence_links and new per-category grouping
  evidence_links = params[:evidence_links] || {}
  evidence_links_by_category = params[:evidence_links_by_category] || {}

    missing_required = []
    # Iterate survey questions directly (categories -> questions)
    @survey.categories.includes(:questions).each do |cat|
      cat.questions.each do |q|
        # Determine if question is a dependent-by-text (starts with If yes/If no)
        dependent_by_text = q.question.to_s.strip.match?(/^\s*If\s+(yes|no)/i) rescue false
        # Numbered questions: no depends_on and not dependent-by-text
        numbered = q.depends_on_question_id.blank? && !dependent_by_text

        # If the question itself is conditional on another question's value, skip unless satisfied
        if q.depends_on_question_id.present? && q.depends_on_value.present?
          dep_val = answers[q.depends_on_question_id.to_s]
          next unless dep_val.to_s == q.depends_on_value.to_s
        end

        # For server-side rule: any numbered question is required
        is_required = numbered

        # Read submitted value from answers[...] (evidence is now submitted as a free-response)
        val = answers[q.id.to_s]

        missing_required << q if is_required && val.blank?
      end
    end

    if missing_required.any?
      flash[:alert] = "Please answer all required questions (marked with *)."
      flash[:missing_required_ids] = missing_required.map(&:id)
      redirect_to survey_path(@survey, missing: missing_required.map(&:id).join(",")) and return
    end

    # Server-side validation for evidence links (both per-question evidence answers and per-category evidence fields)
    invalid_links = []
    drive_regex = QuestionResponse.const_defined?(:DRIVE_URL_REGEX) ? QuestionResponse::DRIVE_URL_REGEX : %r{\Ahttps?://(?:drive\.google\.com|docs\.google\.com)/(?:file/d/|open\?|drive/folders/).+}i

    # Validate per-question evidence answers
    @survey.categories.includes(:questions).each do |cat|
      cat.questions.each do |q|
        next unless q.question_type == "evidence"
        val = answers[q.id.to_s]
        next if val.blank?
        val_str = val.is_a?(String) ? val : val.to_s
        unless val_str =~ drive_regex
          invalid_links << "Question #{q.id}: #{q.question}" unless invalid_links.any? { |s| s.include?("Question #{q.id}:") }
        end
      end
    end

    # Validate per-category evidence links if supplied
    (evidence_links_by_category || {}).each do |cat_id_str, link_val|
      next if link_val.blank?
      link_str = link_val.is_a?(String) ? link_val : link_val.to_s
      unless link_str =~ drive_regex
        invalid_links << "Category #{cat_id_str}: invalid upload link"
      end
    end

    if invalid_links.any?
      flash[:alert] = "One or more upload links are invalid: " + invalid_links.join("; ")
      redirect_to survey_path(@survey) and return
    end

    # Persist answers: ensure QuestionResponse links to surveyresponse
    ActiveRecord::Base.transaction do
      answers.each do |question_id_str, answer_value|
        next unless question_id_str.to_s =~ /^\d+$/
        qid = question_id_str.to_i
        q = Question.find_by(question_id: qid)
        next unless q
        qr = QuestionResponse.find_or_initialize_by(surveyresponse_id: survey_response.id, question_id: qid)
        qr.answer = answer_value
        qr.save!
      end

         # Evidence is stored directly on QuestionResponse.answer for evidence-type questions.
         # The saved answers loop above already persisted question responses, including evidence links.
    end

    redirect_to survey_response_path(survey_response), notice: "Survey submitted successfully!"
  end
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_survey
      @survey = Survey.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def survey_params
      params.require(:survey).permit(:survey_id, :assigned_date, :completion_date, :approval_date, :title, :semester)
    end
end
