# Presentation helpers for survey forms and listings.
module SurveysHelper
     COMPETENCY_DESCRIPTIONS = {
          "Public and Population Health Assessment" => "Historic, current, and anticipated future characteristics and requirements for health care at local, state, regional, and national markets.",
          "Delivery, Organization, and Financing of Health Services and Health Systems" => "Resources, structure, process, and outcomes associated with providing health care informed by theory, data, and analytic methods.",
          "Policy Analysis" => "Creation, analysis, and implications for the rules governing health care structures and delivery systems",
          "Legal & Ethical Bases for Health Services and Health Systems" => "Laws, regulations, and social or other norms that formally or informally provide guidance for health care delivery",
          "Ethics, Accountability, and Self-Assessment" => "Professional and personal values and responsibilities that result in ongoing self-reflection, professional awareness, learning, and development.",
          "Organizational Dynamics" => "Organizational behavior methods and human resource strategies to maximize individual and team development while ensuring cultural awareness and inclusiveness.",
          "Problem Solving, Decision Making, and Critical Thinking" => "Data, analytic methods, and judgment used in support of leadership decisions",
          "Team Building and Collaboration" => "Partnerships that result in functional, motivated, skill-based groups formed to accomplish identifiable goals",
          "Strategic Planning" => "Market and community needs served by defined alternatives, goals, and programs which are supported by appropriate implementation methods.",
          "Business Planning" => "Develop and manage budgets, conduct financial analysis; identify opportunities and threats to organizations using relevant information.",
          "Communication" => "Verbal and non-verbal communication to effectively convey pertinent information",
          "Financial Management" => "Read, understand, and analyze financial statements and audited financial reports",
          "Performance Improvement" => "Data, information, analytic tools, and judgment used to guide goal setting for individuals, teams, and organizations",
          "Project Management" => "Design, plan, execute, and assess tasks and develop appropriate timelines related to performance, structure, and outcomes in the pursuit of stated goals",
          "Systems Thinking" => "Interrelationships between and among constituent parts of an organization",
          "Data Analysis and Information Management" => "Data, information, technology, and supporting structures used in completing assigned tasks",
          "Quantitative Methods for Health Services Delivery" => "Economic, financial, statistical, and other discipline-specific techniques needed to understand, model, assess, and inform health care decision making and address health care questions"
     }.freeze

     COMPETENCY_ALIAS_MAP = {
          /(delivery|financing|health systems)/i => "Delivery, Organization, and Financing of Health Services and Health Systems",
          /(legal|ethical)/i => "Legal & Ethical Bases for Health Services and Health Systems",
          /(public|population)/i => "Public and Population Health Assessment",
          /(project)/i => "Project Management",
          /(quantitative|methods)/i => "Quantitative Methods for Health Services Delivery",
          /(data|information management)/i => "Data Analysis and Information Management"
     }.freeze

     # @param question_text [String]
     # @return [String, nil] description used for competency info tooltip
     def competency_description_for(question_text)
          normalized = question_text.to_s.strip
          return nil if normalized.blank?

          exact_match = COMPETENCY_DESCRIPTIONS.find { |label, _| label.casecmp?(normalized) }
          return exact_match.last if exact_match.present?

          alias_entry = COMPETENCY_ALIAS_MAP.find { |regex, _| normalized.match?(regex) }
          return COMPETENCY_DESCRIPTIONS[alias_entry.last] if alias_entry.present?

          nil
     end

     def survey_assignment_status(assignment)
          if assignment&.completed_at?
               [ "Completed", "success" ]
          elsif assignment.present?
               [ "In Progress", "info" ]
          else
               [ "Not Started", "muted" ]
          end
     end

     def survey_due_badge_text(assignment)
          return "No due date" unless assignment&.due_date.present?

          due_date = assignment.due_date.to_date
          today = Time.zone.today

          if due_date < today
               "Overdue · #{l(due_date, format: :long)}"
          elsif due_date == today
               "Due today"
          else
               "Due #{l(due_date, format: :long)}"
          end
     end
end
