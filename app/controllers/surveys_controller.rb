# Handles student-facing survey listing, completion, and submission flows.
class SurveysController < ApplicationController
  protect_from_forgery except: :save_progress
  before_action :set_survey, only: %i[show submit save_progress]
  before_action :redirect_completed_assignment!, only: %i[show submit save_progress]

  # Lists active surveys ordered by display priority.
  #
  # @return [void]
  def index
    @student = current_student
    assignments = if @student
                    SurveyAssignment
                      .where(student_id: @student.student_id)
                      .select(:id, :survey_id, :assigned_at, :due_date, :completed_at)
    else
                    SurveyAssignment.none
    end

    assigned_survey_ids = assignments.map(&:survey_id)

    @surveys = if assigned_survey_ids.any?
                 Survey.active
                       .includes(:questions, :track_assignments)
                       .where(id: assigned_survey_ids)
                       .ordered
    else
                 Survey.none
    end

    @assignment_lookup = assignments.index_by(&:survey_id)

    @current_semester_label = ProgramSemester.current_name.presence || fallback_semester_label
  end

  # Presents the survey form, pre-populating answers and required flags.
  #
  # @return [void]
  def show
    @return_to = safe_return_to_param
  Rails.logger.info "[EVIDENCE DEBUG] show: session[:invalid_evidence]=#{session[:invalid_evidence].inspect}" # debug session evidence
      scope = @survey.categories.includes(:section, :questions)
      @category_groups = if Category.column_names.include?("position")
                           scope.order(:position, :id)
      else
                           scope.order(:id)
      end
    @existing_answers = {}
    @other_answers = {}
    @computed_required = {}
    student = current_student

    if student
      @survey_assignment = SurveyAssignment.find_by(student_id: student.student_id, survey_id: @survey.id)

      if @survey_assignment&.completed_at?
        due_date = @survey_assignment.due_date
        can_revise = due_date.blank? || due_date >= Time.current
        if can_revise
          flash.now[:notice] ||= "You’re editing a submitted survey. Previous submissions are still visible in your submission history."
        end
      end
    end

    Rails.logger.info "[SHOW DEBUG] Student ID: #{student&.student_id}"
    Rails.logger.info "[SHOW DEBUG] Survey ID: #{@survey.id}"

    if student
      responses = StudentQuestion
                    .where(student_id: student.student_id, question_id: @survey.questions.select(:id))
                    .includes(:question)

      Rails.logger.info "[SHOW DEBUG] Found #{responses.count} saved responses"

      responses.each do |response|
        ans = response.answer
        # Normalize stored shapes so views get a text answer and a separate rating when present
        if ans.is_a?(Hash)
          if response.question.question_type == "evidence" && ans["link"].present?
            @existing_answers[response.question_id.to_s] = ans["link"]
          elsif response.question.choice_question? && ans["answer"].present?
            @existing_answers[response.question_id.to_s] = ans["answer"]
            if ans["text"].present? || response.question.answer_option_requires_text?(ans["answer"].to_s)
              @other_answers[response.question_id.to_s] = ans["text"].to_s
            end
          else
            # For competency/non-evidence questions we previously stored {"text"=>..., "rating"=>n}
            text_value = ans["text"] || ans["answer"]
            text_value = ans["rating"].to_s if text_value.blank? && ans["rating"].present?
            @existing_answers[response.question_id.to_s] = text_value
          end
        else
          # Use string key to match view's expectation
          @existing_answers[response.question_id.to_s] = ans
        end
        Rails.logger.info "[SHOW DEBUG] Question #{response.question_id}: #{ans.inspect}"
      end
    end

    Rails.logger.info "[SHOW DEBUG] Total existing answers: #{@existing_answers.size}"
    Rails.logger.info "[SHOW DEBUG] Answer keys: #{@existing_answers.keys.inspect}"

    @category_groups.each do |category|
      category.questions.each do |question|
        required = question.is_required?

        if !required && question.choice_question?
          option_values = question.answer_option_values
          options = option_values.map(&:strip).map(&:downcase)
          # Exception: flexibility scale questions (1-5) should remain optional
          numeric_scale = %w[1 2 3 4 5]
          has_numeric_scale = (numeric_scale - options).empty?
          is_flexibility_scale = has_numeric_scale && question.question_text.to_s.downcase.include?("flexible")
          required = !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
        end

        @computed_required[question.id] = required
      end
    end


    @invalid_evidence ||= nil
  end

  # Processes survey submissions, validating required answers and evidence
  # links before persisting student responses.
  #
  # @return [void]
  def submit
  Rails.logger.info "[EVIDENCE DEBUG] SurveysController#submit called"
    student = current_student

    unless student
      redirect_to student_dashboard_path, alert: "Student record not found for current user."
      return
    end

    assignment = SurveyAssignment.find_by(student_id: student.student_id, survey_id: @survey.id)
    if assignment&.completed_at? && assignment.due_date.present? && assignment.due_date < Time.current
      survey_response = SurveyResponse.build(student: student, survey: @survey)
      redirect_to survey_response_path(survey_response), alert: "This survey has already been submitted and the due date has passed. It can only be viewed."
      return
    end

    raw_answers = params[:answers]
    answers = case raw_answers
    when ActionController::Parameters
                raw_answers.to_unsafe_h
    when Hash
                raw_answers
    else
                {}
    end
    answers = answers.stringify_keys

    raw_other_answers = params[:other_answers]
    other_answers = case raw_other_answers
    when ActionController::Parameters
              raw_other_answers.to_unsafe_h
    when Hash
              raw_other_answers
    else
              {}
    end
    other_answers = other_answers.stringify_keys
    @first_error_question_id = nil
    @first_error_section_dom_id = nil
    answers_present = answers.values.any? do |value|
      case value
      when Hash
        value.values.any?(&:present?)
      when Array
        value.any?(&:present?)
      else
        value.present?
      end
    end
    @scroll_to_form_top = !answers_present

    # Build a questions map for efficient lookups
    questions_map = @survey.questions.includes(category: :section).index_by(&:id)
    allowed_question_ids = questions_map.keys

    missing_required = []
    invalid_links = []

    questions_map.each_value do |question|
      submitted_value = answers[question.id.to_s]

      if question.choice_question?
        selected_value = submitted_value.to_s
        if question.answer_option_requires_text?(selected_value) || selected_value.casecmp?("Other")
          submitted_value = {
            "answer" => selected_value,
            "text" => other_answers[question.id.to_s].to_s
          }
        end
      end

      # Apply the same required logic as in show action
      required = question.is_required?
      if !required && question.choice_question?
        option_values = question.answer_option_values
        options = option_values.map(&:strip).map(&:downcase)
        numeric_scale = %w[1 2 3 4 5]
        has_numeric_scale = (numeric_scale - options).empty?
        is_flexibility_scale = has_numeric_scale && question.question_text.to_s.downcase.include?("flexible")
        required = !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
      end

      if required && submitted_value.to_s.strip.blank?
        missing_required << question
      end

      # Debug evidence question type and value
      if submitted_value.present?
        Rails.logger.info "[EVIDENCE DEBUG] QID: #{question.id}, TYPE: #{question.question_type.inspect}, VALUE: #{submitted_value.inspect}"
      end
      # Only validate evidence questions for Google-hosted links
      if question.question_type == "evidence" && submitted_value.present?
        value_str = submitted_value.is_a?(String) ? submitted_value : submitted_value.to_s
        # 1) basic format check
        if value_str !~ StudentQuestion::GOOGLE_URL_REGEX
          Rails.logger.info "[EVIDENCE DEBUG] INVALID evidence format for QID: #{question.id} VALUE: #{value_str.inspect}"
          invalid_links << question
        else
          # 2) accessibility check (HEAD with redirects, GET fallback)
          accessible, reason = evidence_accessible?(value_str)
          Rails.logger.info "[EVIDENCE DEBUG] access check QID: #{question.id} url=#{value_str} => accessible=#{accessible} reason=#{reason}"
          invalid_links << question unless accessible
        end
      end
    end

    if missing_required.any? || invalid_links.any?
      scope = @survey.categories.includes(:section, :questions)
      @category_groups = if Category.column_names.include?("position")
                           scope.order(:position, :id)
      else
                           scope.order(:id)
      end
      @existing_answers = answers
      @other_answers = other_answers
      @computed_required = {}
      @invalid_evidence = invalid_links.map(&:id)
      error_candidates = (missing_required + invalid_links).map(&:id)
      ordered_ids = question_ids_in_display_order(@category_groups)
      ordered_ids = @survey.questions.order(:question_order).pluck(:id) if ordered_ids.blank?
      @first_error_question_id = (ordered_ids & error_candidates).first || error_candidates.first
      if @first_error_question_id
        first_error_question = questions_map[@first_error_question_id]
        first_error_category = first_error_question&.category
        first_error_section = first_error_category&.section
        @first_error_section_dom_id = if first_error_section.present?
                                        "survey-section-#{first_error_section.id}"
        elsif first_error_category.present?
                                        "survey-category-#{first_error_category.id}"
        end
      end
      alert_parts = [ "Unable to submit your responses." ]
      alert_parts << "Please answer all required questions." if missing_required.any?
      if invalid_links.any?
        alert_parts << "Please fix the highlighted evidence links by setting sharing to 'Anyone with the link can view.'"
      end
      flash.now[:alert] = alert_parts.join(" ")
      @category_groups.each do |category|
        category.questions.each do |question|
          required = question.is_required?
          if !required && question.choice_question?
            option_values = question.answer_option_values
            options = option_values.map(&:strip).map(&:downcase)
            numeric_scale = %w[1 2 3 4 5]
            has_numeric_scale = (numeric_scale - options).empty?
            is_flexibility_scale = has_numeric_scale && question.question_text.to_s.downcase.include?("flexible")
            required = !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
          end
          @computed_required[question.id] = required
        end
      end

      # Persist provided answers even when submit fails
      ActiveRecord::Base.transaction do
        allowed_question_ids.each do |question_id|
          submitted_value = answers[question_id.to_s]

          question = questions_map[question_id]
          if question&.choice_question?
            selected_value = submitted_value.to_s
            if question.answer_option_requires_text?(selected_value) || selected_value.casecmp?("Other")
              submitted_value = { "answer" => selected_value, "text" => other_answers[question_id.to_s].to_s }
            end
          end

          record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question_id)
          record.advisor_id ||= student.advisor_id

          if submitted_value.present?
            record.answer = submitted_value
            record.save(validate: false)
          elsif record.persisted?
            record.destroy!
          end
        end
      end
      render :show, status: :unprocessable_entity and return
    end

    ActiveRecord::Base.transaction do
      allowed_question_ids.each do |question_id|
        submitted_value = answers[question_id.to_s]

        question = questions_map[question_id]
        if question&.choice_question?
          selected_value = submitted_value.to_s
          if question.answer_option_requires_text?(selected_value) || selected_value.casecmp?("Other")
            submitted_value = { "answer" => selected_value, "text" => other_answers[question_id.to_s].to_s }
          end
        end

        record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question_id)
        record.advisor_id ||= student.advisor_id

        if submitted_value.present?
          record.answer = submitted_value
          record.save!
        elsif record.persisted?
          record.destroy!
        end
      end
    end

    begin
      assignment = nil
      was_completed = nil

      ActiveRecord::Base.transaction do
        Rails.logger.info "[SUBMIT] Creating/updating assignment for survey #{@survey.id}, student #{student.student_id}"

        assignment = SurveyAssignment.lock.find_by(survey_id: @survey.id, student_id: student.student_id)
        unless assignment
          begin
            assignment = SurveyAssignment.create!(
              survey_id: @survey.id,
              student_id: student.student_id,
              advisor_id: student.advisor_id,
              assigned_at: Time.current
            )
          rescue ActiveRecord::RecordNotUnique
            assignment = SurveyAssignment.lock.find_by!(survey_id: @survey.id, student_id: student.student_id)
          end
        end

        assignment.advisor_id ||= student.advisor_id
        assignment.assigned_at ||= Time.current
        assignment.save! if assignment.changed?

        was_completed = assignment.completed_at?

        Rails.logger.info "[SUBMIT] Marking assignment #{assignment.id} as completed"
        assignment.mark_completed!

        begin
          SurveyResponseVersion.capture_current!(
            student: student,
            survey: @survey,
            assignment: assignment,
            actor_user: current_user,
            event: (was_completed ? :revised : :submitted),
            skip_if_unchanged: true
          )
        rescue StandardError => version_error
          Rails.logger.warn "[SUBMIT] Failed to capture survey response version: #{version_error.class}: #{version_error.message}"
        end
      end

      Rails.logger.info "[SUBMIT] Enqueueing notification job"
      begin
        SurveyNotificationJob.perform_later(event: :completed, survey_assignment_id: assignment.id)
        SurveyNotificationJob.perform_later(event: :response_submitted, survey_assignment_id: assignment.id)
      rescue StandardError => job_error
        # Don't fail submission if job enqueue fails
        Rails.logger.warn "[SUBMIT] Failed to enqueue notification job: #{job_error.class}: #{job_error.message}"
      end

      Rails.logger.info "[SUBMIT] Building survey response"
      survey_response = SurveyResponse.build(student: student, survey: @survey)
      progress_summary = survey_response.progress_summary
      survey_response_id = survey_response.id
      notice_message = build_progress_notice(
        prefix: "Survey submitted successfully!",
        progress: progress_summary
      )

      Rails.logger.info "[SUBMIT] Redirecting to survey response path with ID: #{survey_response_id}"
      begin
        redirect_to survey_response_path(survey_response_id), notice: notice_message
      rescue ActionController::UrlGenerationError => url_error
        Rails.logger.error "[SUBMIT] URL generation failed: #{url_error.message}"
        redirect_to student_dashboard_path, notice: notice_message
      end
    rescue StandardError => e
      Rails.logger.error "[SUBMIT ERROR] Failed to complete survey submission: #{e.class}: #{e.message}"
      Rails.logger.error "[SUBMIT ERROR] Backtrace:\n#{e.backtrace.first(20).join("\n")}"

      # Re-raise if it's an ActiveRecord error that should propagate
      raise if e.is_a?(ActiveRecord::RecordInvalid) || e.is_a?(ActiveRecord::RecordNotSaved)

      redirect_to survey_path(@survey), alert: "An error occurred while submitting the survey. Please try again or contact support if the problem persists."
    end
  end

  # Saves the current survey progress without validating required fields.
  # Allows students to save their work and continue later.
  #
  # @return [void]
  def save_progress
    student = current_student

    unless student
      redirect_to student_dashboard_path, alert: "Student record not found for current user."
      return
    end

    assignment = SurveyAssignment.find_by(student_id: student.student_id, survey_id: @survey.id)
    if assignment&.completed_at?
      if assignment.due_date.present? && assignment.due_date < Time.current
        survey_response = SurveyResponse.build(student: student, survey: @survey)
        redirect_to survey_response_path(survey_response), alert: "This survey has already been submitted and the due date has passed. It can only be viewed."
      else
        redirect_to survey_path(@survey), alert: "This survey has already been submitted. Use Submit Survey to update your answers."
      end
      return
    end

    raw_answers = params[:answers]
    answers = case raw_answers
    when ActionController::Parameters
          raw_answers.to_unsafe_h
    when Hash
          raw_answers
    else
          {}
    end
    answers = answers.stringify_keys

    raw_other_answers = params[:other_answers]
    other_answers = case raw_other_answers
    when ActionController::Parameters
              raw_other_answers.to_unsafe_h
    when Hash
              raw_other_answers
    else
              {}
    end
    other_answers = other_answers.stringify_keys

    questions_map = @survey.questions.index_by(&:id)
    allowed_question_ids = questions_map.keys

    Rails.logger.info "[SAVE_PROGRESS DEBUG] Student ID: #{student.student_id}"
    Rails.logger.info "[SAVE_PROGRESS DEBUG] Answers received: #{answers.inspect}"
    Rails.logger.info "[SAVE_PROGRESS DEBUG] Allowed question IDs: #{allowed_question_ids.inspect}"

    saved_count = 0
    ActiveRecord::Base.transaction do
      allowed_question_ids.each do |question_id|
        submitted_value = answers[question_id.to_s]
        question = questions_map[question_id]

        if question&.choice_question?
          selected_value = submitted_value.to_s
          if question.answer_option_requires_text?(selected_value) || selected_value.casecmp?("Other")
            submitted_value = { "answer" => selected_value, "text" => other_answers[question_id.to_s].to_s }
          end
        end
        Rails.logger.info "[SAVE_PROGRESS DEBUG] Question #{question_id}: value=#{submitted_value.inspect}"

        record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question_id)
        record.advisor_id ||= student.advisor_id

        if submitted_value.present?
          record.answer = submitted_value
          # Skip validations when saving progress; validations happen on submit
          if record.save(validate: false)
            saved_count += 1
            Rails.logger.info "[SAVE_PROGRESS DEBUG] Saved question #{question_id} with value: #{submitted_value} (validations skipped)"
          else
            Rails.logger.warn "[SAVE_PROGRESS DEBUG] Failed to save question #{question_id} during save_progress (validations skipped)"
          end
        elsif record.persisted?
          record.destroy!
          Rails.logger.info "[SAVE_PROGRESS DEBUG] Destroyed empty answer for question #{question_id}"
        end
      end
    end

    Rails.logger.info "[SAVE_PROGRESS DEBUG] Total saved: #{saved_count} answers"

    survey_response = SurveyResponse.build(student: student, survey: @survey)
    progress_summary = survey_response.progress_summary
    notice_message = build_progress_notice(
      prefix: "Progress saved! You can continue later.",
      progress: progress_summary
    )

    redirect_to student_dashboard_path, notice: notice_message
  end

  private

  # Finds the survey requested by the route.
  #
  # @return [void]
  def set_survey
    @survey = Survey.includes(:legend, categories: %i[section questions]).find(params[:id])
  end

  def question_ids_in_display_order(category_groups)
    Array(category_groups).flat_map do |category|
      next [] unless category

      questions = category.questions
      ordered_questions = if questions.respond_to?(:loaded?) && questions.loaded?
                            questions.sort_by do |q|
                              parent_id = q.respond_to?(:parent_question_id) ? q.parent_question_id : nil
                              group_key = (parent_id || q.id).to_i
                              sub_flag = q.respond_to?(:sub_question?) ? (q.sub_question? ? 1 : 0) : (parent_id ? 1 : 0)
                              sub_order = q.respond_to?(:sub_question_order) ? q.sub_question_order.to_i : 0
                              [ q.question_order.to_i, group_key, sub_flag, sub_order, q.id.to_i ]
                            end
      else
                            relation = questions.order(:question_order)

                            if Question.sub_question_columns_supported?
                              relation
                                .order(Arel.sql("COALESCE(parent_question_id, id)"))
                                .order(Arel.sql("CASE WHEN parent_question_id IS NULL THEN 0 ELSE 1 END"))
                                .order(:sub_question_order, :id)
                                .to_a
                            else
                              relation.order(:id).to_a
                            end
      end
      ordered_questions.map(&:id)
    end
  end

  # Prevents students from editing a survey that has already been submitted.
  # Redirects them to the read-only SurveyResponse view instead.
  def redirect_completed_assignment!
    student = current_student
    return unless student && @survey

    assignment = SurveyAssignment.find_by(student_id: student.student_id, survey_id: @survey.id)
    return unless assignment&.completed_at?

    # Allow unlimited revisions if no due date exists, or when the due date
    # hasn't passed yet.
    return if assignment.due_date.blank?
    return if assignment.due_date >= Time.current

    survey_response = SurveyResponse.build(student: student, survey: @survey)
    redirect_to survey_response_path(survey_response), alert: "This survey has already been submitted and the due date has passed. It can only be viewed." and return
  end

  # Checks if a Google-hosted link (Drive/Docs/Sites) is publicly accessible.
  # Returns [Boolean accessible, Symbol reason]
  def evidence_accessible?(url)
    require "uri"
    require "net/http"

    begin
      uri = URI.parse(url)
    rescue URI::InvalidURIError
      return [ false, :invalid ]
    end

    return [ false, :invalid ] unless uri.is_a?(URI::HTTPS)

  host = uri.host.to_s.downcase
  allowlist_hosts = %w[drive.google.com docs.google.com sites.google.com]
  allowlist_suffixes = %w[googleusercontent.com]
  allowlisted_host = lambda do |candidate|
    candidate_host = candidate.to_s.downcase
    allowlist_hosts.include?(candidate_host) || allowlist_suffixes.any? { |suffix| candidate_host == suffix || candidate_host.end_with?("." + suffix) }
  end
  return [ false, :invalid ] unless allowlisted_host.call(host)

    max_redirects = 3
    redirects = 0
    current_uri = uri

  # Special handling for Google Docs document links: use export endpoint to test read-access
  if host.end_with?("docs.google.com") && uri.path =~ %r{^/(document)/d/([A-Za-z0-9_-]+)}
      doc_type = Regexp.last_match(1)
      doc_id = Regexp.last_match(2)
      export_uri = URI.parse("https://docs.google.com/#{doc_type}/d/#{doc_id}/export?format=txt")
      begin
        http = Net::HTTP.new(export_uri.host, export_uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 5
        req = Net::HTTP::Get.new(export_uri.request_uri)
        req["Range"] = "bytes=0-1023"
        req["User-Agent"] = "HealthProfessions/1.0"
        resp = http.request(req)
        case resp
        when Net::HTTPSuccess
          return [ true, :ok ]
        when Net::HTTPRedirection
          # If export redirects to non-allowlisted host, likely requires auth
          location = resp["location"]
          if location
            new_host = (URI.parse(location).host.to_s)
            unless allowlisted_host.call(new_host)
              # Don't hard-fail here; fall back to generic checks in case export is restricted but page is public
              Rails.logger.info "[EVIDENCE DEBUG] export redirect to non-allowlisted host: #{new_host}, will fall back to generic checks"
            end
          end
        # fall through to generic logic
        when Net::HTTPForbidden, Net::HTTPNotFound
          # Some public docs may disable download/export; fall back to generic page checks
          Rails.logger.info "[EVIDENCE DEBUG] export returned #{resp.code}, falling back to generic checks"
        # fall through
        else
             # fall through to generic logic
        end
      rescue Net::OpenTimeout, Net::ReadTimeout
        return [ false, :timeout ]
      rescue StandardError => e
        Rails.logger.info "[EVIDENCE DEBUG] export check exception ignored: #{e.class}: #{e.message}"
           # fall through
      end
  end

    loop do
      begin
        http = Net::HTTP.new(current_uri.host, current_uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 5

        head = Net::HTTP::Head.new(current_uri.request_uri)
        head["User-Agent"] = "HealthProfessions/1.0"
        response = http.request(head)

        case response
        when Net::HTTPSuccess
          # Even with 200, page might be an interstitial requiring auth; sniff small content (avoid generic 'sign in')
          begin
            sniff_http = Net::HTTP.new(current_uri.host, current_uri.port)
            sniff_http.use_ssl = true
            sniff_http.open_timeout = 5
            sniff_http.read_timeout = 5
            sniff = Net::HTTP::Get.new(current_uri.request_uri)
            sniff["Range"] = "bytes=0-2047"
            sniff["User-Agent"] = "HealthProfessions/1.0"
            sniff_resp = sniff_http.request(sniff)
            if sniff_resp.is_a?(Net::HTTPSuccess)
              body_start = (sniff_resp.body || "")
              if body_start =~ /(you need access|request access|sign in to continue|don[’']t have access|do not have access)/i
                return [ false, :forbidden ]
              end
              # If page contains clear public markers, consider accessible
              if body_start =~ /(open with google docs|file|view only|anyone with the link)/i
                return [ true, :ok ]
              end
            end
          rescue Net::OpenTimeout, Net::ReadTimeout
            return [ false, :timeout ]
          rescue StandardError => e
            Rails.logger.info "[EVIDENCE DEBUG] sniff exception ignored: #{e.class}: #{e.message}"
          end
          return [ true, :ok ]
        when Net::HTTPRedirection
          if (location = response["location"])
            redirects += 1
            return [ false, :too_many_redirects ] if redirects > max_redirects
            current_uri = URI.parse(location)
            # Block redirects to hosts outside the Google family (e.g., third-party login walls)
            new_host = current_uri.host.to_s
            unless allowlisted_host.call(new_host)
              return [ false, :forbidden ]
            end
            next
          else
            return [ false, :error ]
          end
        when Net::HTTPForbidden
          return [ false, :forbidden ]
        when Net::HTTPNotFound
          return [ false, :not_found ]
        when Net::HTTPMethodNotAllowed
          # Fallback to minimal GET when HEAD not allowed
          get = Net::HTTP::Get.new(current_uri.request_uri)
          get["Range"] = "bytes=0-0"
          get["User-Agent"] = "HealthProfessions/1.0"
          get_resp = http.request(get)
          if get_resp.is_a?(Net::HTTPSuccess)
            # Sniff small portion for access-required hints
            begin
              sniff_http = Net::HTTP.new(current_uri.host, current_uri.port)
              sniff_http.use_ssl = true
              sniff_http.open_timeout = 5
              sniff_http.read_timeout = 5
              sniff = Net::HTTP::Get.new(current_uri.request_uri)
              sniff["Range"] = "bytes=0-2047"
              sniff["User-Agent"] = "HealthProfessions/1.0"
              sniff_resp = sniff_http.request(sniff)
              if sniff_resp.is_a?(Net::HTTPSuccess)
                body_start = (sniff_resp.body || "")
                if body_start =~ /(you need access|request access|sign in to continue|don[’']t have access|do not have access)/i
                  return [ false, :forbidden ]
                end
              end
            rescue Net::OpenTimeout, Net::ReadTimeout
              return [ false, :timeout ]
            rescue StandardError => e
              Rails.logger.info "[EVIDENCE DEBUG] sniff exception ignored: #{e.class}: #{e.message}"
            end
            return [ true, :ok ]
          else
            return [ false, :error ]
          end
        else
          return [ false, :error ]
        end
      rescue Net::OpenTimeout, Net::ReadTimeout
        return [ false, :timeout ]
      rescue StandardError => e
        Rails.logger.warn "[EVIDENCE DEBUG] exception during access check: #{e.class}: #{e.message}"
        return [ false, :error ]
      end
    end
  end

  def build_progress_notice(prefix:, progress: {})
    total_questions = progress[:total_questions].to_i
    answered_total = progress[:answered_total].to_i
    return prefix if total_questions.zero?

    description = [
      "#{answered_total}/#{total_questions} questions answered",
      progress[:total_required].to_i.positive? ? "(#{progress[:answered_required]}/#{progress[:total_required]} required)" : nil
    ].compact.join(" ")

    message = [ prefix.to_s.strip, description ].reject(&:blank?).join(" ").strip
    message.ends_with?(".") ? message : "#{message}."
  end
end
