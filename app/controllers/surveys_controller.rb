# Handles student-facing survey listing, completion, and submission flows.
class SurveysController < ApplicationController
  protect_from_forgery except: :save_progress
  before_action :set_survey, only: %i[show submit save_progress]

  # Lists active surveys ordered by display priority.
  #
  # @return [void]
  def index
    @surveys = Survey.active.ordered
  end

  # Presents the survey form, pre-populating answers and required flags.
  #
  # @return [void]
  def show
  Rails.logger.info "[EVIDENCE DEBUG] show: session[:invalid_evidence]=#{session[:invalid_evidence].inspect}" # debug session evidence
    @category_groups = @survey.categories.includes(:questions).order(:id)
    @existing_answers = {}
    @computed_required = {}
    student = current_student

    Rails.logger.info "[SHOW DEBUG] Student ID: #{student&.student_id}"
    Rails.logger.info "[SHOW DEBUG] Survey ID: #{@survey.id}"

    if student
      responses = StudentQuestion
                    .where(student_id: student.student_id, question_id: @survey.questions.select(:id))
                    .includes(:question)

      Rails.logger.info "[SHOW DEBUG] Found #{responses.count} saved responses"

      @existing_ratings = {}
      responses.each do |response|
        ans = response.answer
        if response.question.question_type == "evidence" && ans.is_a?(Hash)
          @existing_answers[response.question_id.to_s] = ans["link"]
          @existing_ratings[response.question_id.to_s] = ans["rating"]
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

        if !required && question.question_type_multiple_choice?
          options = question.answer_options_list.map(&:strip).map(&:downcase)
          # Exception: flexibility scale questions (1-5) should remain optional
          is_flexibility_scale = (options == %w[1 2 3 4 5]) &&
                                 question.question_text.to_s.downcase.include?("flexible")
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

    answers = params[:answers] || {}

    allowed_question_ids = @survey.questions.pluck(:id)

    missing_required = []
    invalid_links = []
    missing_ratings = []

    @survey.questions.each do |question|
      submitted_value = answers[question.id.to_s]

      # Apply the same required logic as in show action
      required = question.is_required?
      if !required && question.question_type_multiple_choice?
        options = question.answer_options_list.map(&:strip).map(&:downcase)
        is_flexibility_scale = (options == %w[1 2 3 4 5]) &&
                               question.question_text.to_s.downcase.include?("flexible")
        required = !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
      end

      if required && submitted_value.to_s.strip.blank?
        missing_required << question
      end

      # Debug evidence question type and value
      if submitted_value.present?
        Rails.logger.info "[EVIDENCE DEBUG] QID: #{question.id}, TYPE: #{question.question_type.inspect}, VALUE: #{submitted_value.inspect}"
      end
      # Only validate evidence questions for Google Drive link
      if question.question_type == "evidence" && submitted_value.present?
        value_str = submitted_value.is_a?(String) ? submitted_value : submitted_value.to_s
        # 1) basic format check
        if value_str !~ StudentQuestion::DRIVE_URL_REGEX
          Rails.logger.info "[EVIDENCE DEBUG] INVALID evidence format for QID: #{question.id} VALUE: #{value_str.inspect}"
          invalid_links << question
        else
          # 2) accessibility check (HEAD with redirects, GET fallback)
          accessible, reason = evidence_accessible?(value_str)
          Rails.logger.info "[EVIDENCE DEBUG] access check QID: #{question.id} url=#{value_str} => accessible=#{accessible} reason=#{reason}"
          invalid_links << question unless accessible
        end
      end

      # Require self-rating for evidence questions outside Employment Information
      if question.question_type == "evidence"
        category_name = question.category&.name.to_s
        rating_required = category_name != "Employment Information"
        if rating_required
          rating_val = params.dig(:answers_rating, question.id.to_s)
          if rating_val.to_s.strip.blank?
            missing_ratings << question
          end
        end
      end
    end

    if missing_required.any? || invalid_links.any? || missing_ratings.any?
      @category_groups = @survey.categories.includes(:questions).order(:id)
      @existing_answers = answers
      @existing_ratings = (params[:answers_rating] || {}).transform_keys(&:to_s)
      @computed_required = {}
      @invalid_evidence = invalid_links.map(&:id)
      @missing_rating_ids = missing_ratings.map(&:id)
      @category_groups.each do |category|
        category.questions.each do |question|
          required = question.is_required?
          if !required && question.question_type_multiple_choice?
            options = question.answer_options_list.map(&:strip).map(&:downcase)
            is_flexibility_scale = (options == %w[1 2 3 4 5]) &&
                                   question.question_text.to_s.downcase.include?("flexible")
            required = !(options == %w[yes no] || options == %w[no yes] || is_flexibility_scale)
          end
          @computed_required[question.id] = required
        end
      end

      # Persist all provided answers (including self-ratings) even when submit fails
      allowed_question_ids = @survey.questions.pluck(:id)
      ActiveRecord::Base.transaction do
        allowed_question_ids.each do |question_id|
          submitted_value = answers[question_id.to_s]
          record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question_id)
          record.advisor_id ||= student.advisor_id

          question = @survey.questions.find { |q| q.id == question_id }
          if question&.question_type == "evidence"
            rating_value = params.dig(:answers_rating, question_id.to_s)
            if submitted_value.present? || rating_value.present?
              combined = { "link" => submitted_value, "rating" => (rating_value.presence && rating_value.to_i) }.compact
              record.answer = combined
              record.save(validate: false)
            elsif record.persisted?
              record.destroy!
            end
          else
            if submitted_value.present?
              record.answer = submitted_value
              record.save(validate: false)
            elsif record.persisted?
              record.destroy!
            end
          end
        end
      end
      render :show, status: :unprocessable_entity and return
    end

    ActiveRecord::Base.transaction do
      allowed_question_ids.each do |question_id|
        submitted_value = answers[question_id.to_s]
        record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question_id)
        record.advisor_id ||= student.advisor_id

        question = @survey.questions.find { |q| q.id == question_id }
        if question&.question_type == "evidence"
          rating_value = params.dig(:answers_rating, question_id.to_s)
          if submitted_value.present? || rating_value.present?
            combined = { "link" => submitted_value, "rating" => (rating_value.presence && rating_value.to_i) }.compact
            record.answer = combined
            record.save!
          elsif record.persisted?
            record.destroy!
          end
        else
          if submitted_value.present?
            record.answer = submitted_value
            record.save!
          elsif record.persisted?
            record.destroy!
          end
        end
      end
    end

    assignment = SurveyAssignment.find_or_initialize_by(survey_id: @survey.id, student_id: student.student_id)
    assignment.advisor_id ||= student.advisor_id
    assignment.assigned_at ||= Time.current
    assignment.save! if assignment.new_record? || assignment.changed?
    assignment.mark_completed!
    SurveyNotificationJob.perform_later(event: :completed, survey_assignment_id: assignment.id)

    survey_response_id = SurveyResponse.build(student: student, survey: @survey).id
    redirect_to survey_response_path(survey_response_id), notice: "Survey submitted successfully!"
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

    answers = params[:answers] || {}
    allowed_question_ids = @survey.questions.pluck(:id)

    Rails.logger.info "[SAVE_PROGRESS DEBUG] Student ID: #{student.student_id}"
    Rails.logger.info "[SAVE_PROGRESS DEBUG] Answers received: #{answers.inspect}"
    Rails.logger.info "[SAVE_PROGRESS DEBUG] Allowed question IDs: #{allowed_question_ids.inspect}"

    saved_count = 0
    ActiveRecord::Base.transaction do
      allowed_question_ids.each do |question_id|
        submitted_value = answers[question_id.to_s]
        Rails.logger.info "[SAVE_PROGRESS DEBUG] Question #{question_id}: value=#{submitted_value.inspect}"

        record = StudentQuestion.find_or_initialize_by(student_id: student.student_id, question_id: question_id)
        record.advisor_id ||= student.advisor_id

        question = @survey.questions.find { |q| q.id == question_id }
        if question&.question_type == "evidence"
          rating_value = params.dig(:answers_rating, question_id.to_s)
          if submitted_value.present? || rating_value.present?
            combined = { "link" => submitted_value, "rating" => (rating_value.presence && rating_value.to_i) }.compact
            record.answer = combined
            if record.save(validate: false)
              saved_count += 1
              Rails.logger.info "[SAVE_PROGRESS DEBUG] Saved evidence+rating #{question_id} (validations skipped)"
            end
          elsif record.persisted?
            record.destroy!
            Rails.logger.info "[SAVE_PROGRESS DEBUG] Destroyed empty evidence+rating for question #{question_id}"
          end
        else
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
    end

    Rails.logger.info "[SAVE_PROGRESS DEBUG] Total saved: #{saved_count} answers"
    redirect_to survey_path(@survey), notice: "Progress saved! You can continue later."
  end

  private

  # Finds the survey requested by the route.
  #
  # @return [void]
  def set_survey
    @survey = Survey.find(params[:id])
  end

  # Checks if a Google Drive/Docs link is publicly accessible.
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

  host = uri.host.to_s
  allowlist = %w[drive.google.com docs.google.com googleusercontent.com]
  return [ false, :invalid ] unless allowlist.any? { |h| host == h || host.end_with?("." + h) }

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
            unless allowlist.any? { |h| new_host == h || new_host.end_with?("." + h) }
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
            # Block redirects to non-allowlisted hosts (e.g., accounts.google.com); allow googleusercontent.com
            new_host = current_uri.host.to_s
            unless allowlist.any? { |h| new_host == h || new_host.end_with?("." + h) }
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
end
