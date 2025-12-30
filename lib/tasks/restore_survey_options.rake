# frozen_string_literal: true

require "yaml"

namespace :surveys do
  desc "Restore choice question answer_options from db/data/program_surveys.yml for a specific survey_id"
  task :restore_options_from_templates, [ :survey_id ] => :environment do |_t, args|
    survey_id = args[:survey_id].to_s.strip
    if survey_id.blank?
      abort "Usage: bin/rails surveys:restore_options_from_templates[SURVEY_ID]"
    end

    survey = Survey.find(survey_id)

    template_path = Rails.root.join("db", "data", "program_surveys.yml")
    abort "Template file not found: #{template_path}" unless File.exist?(template_path)

    template_data = YAML.safe_load_file(template_path, aliases: true)
    templates = Array(template_data.fetch("surveys"))

    survey_semester_name = survey.program_semester&.name.to_s.strip

    template = templates.find do |definition|
      title = definition["title"].to_s.strip
      semester = definition["program_semester"].to_s.strip
      title.casecmp?(survey.title.to_s.strip) && semester.casecmp?(survey_semester_name)
    end

    if template.blank?
      abort "No template found for survey '#{survey.title}' (#{survey_semester_name})."
    end

    answer_options_for = lambda do |options|
      return nil if options.blank?

      normalized = Array(options).filter_map do |entry|
        case entry
        when String
          entry.to_s.strip.presence
        when Array
          next if entry.empty?
          label = entry[0].to_s.strip
          value = entry[1].to_s.strip
          next if label.blank? || value.blank?
          [ label, value ]
        when Hash
          label = (entry["label"] || entry[:label]).to_s.strip
          value = (entry["value"] || entry[:value] || label).to_s.strip
          next if label.blank? || value.blank?

          requires_text = entry.key?("requires_text") || entry.key?(:requires_text) ? !!(entry["requires_text"] || entry[:requires_text]) : nil
          requires_text = entry.key?("other_text") || entry.key?(:other_text) ? !!(entry["other_text"] || entry[:other_text]) : requires_text
          requires_text = entry.key?("other") || entry.key?(:other) ? !!(entry["other"] || entry[:other]) : requires_text

          definition = { "label" => label, "value" => value }
          definition["requires_text"] = true if requires_text
          definition
        else
          entry.to_s.strip.presence
        end
      end

      normalized.to_json
    end

    template_categories = Array(template.fetch("categories", []))

    # Build lookup maps keyed by category name.
    template_questions_by_category = {}
    template_sub_questions_by_parent = {}

    template_categories.each do |cat_def|
      cat_name = cat_def["name"].to_s.strip
      qs = Array(cat_def.fetch("questions", []))
      template_questions_by_category[cat_name] = qs

      qs.each do |qdef|
        next unless qdef.is_a?(Hash)
        parent_key = [ cat_name, qdef["order"].to_i, qdef["text"].to_s.strip ]
        template_sub_questions_by_parent[parent_key] = Array(qdef.fetch("sub_questions", []))
      end
    end

    restored = 0
    skipped = 0
    missing = 0

    Survey.transaction do
      survey.categories.includes(:questions).find_each do |category|
        cat_name = category.name.to_s.strip
        template_questions = template_questions_by_category[cat_name]
        if template_questions.blank?
          missing += category.questions.size
          next
        end

        # Parent questions (also used to locate template sub-questions)
        category.questions.select { |q| q.parent_question_id.blank? }.each do |question|
          next unless %w[multiple_choice dropdown].include?(question.question_type)

          qdef = template_questions.find do |qd|
            qd.is_a?(Hash) && qd["order"].to_i == question.question_order.to_i && qd["text"].to_s.strip == question.question_text.to_s.strip
          end

          raw = question.answer_options.to_s.strip
          needs_restore = raw.blank? || raw == "[]"

          if qdef.blank?
            missing += 1 if needs_restore
          elsif needs_restore
            restored_value = answer_options_for.call(qdef["options"])
            if restored_value.blank?
              missing += 1
            else
              question.update!(answer_options: restored_value)
              restored += 1
            end
          else
            skipped += 1
          end

          # Sub-questions, if any (restore even when parent didn't need restore)
          next if qdef.blank?

          parent_key = [ cat_name, qdef["order"].to_i, qdef["text"].to_s.strip ]
          sub_defs = template_sub_questions_by_parent[parent_key]
          next if sub_defs.blank?

          question.sub_questions.each do |sub_q|
            next unless %w[multiple_choice dropdown].include?(sub_q.question_type)

            sub_raw = sub_q.answer_options.to_s.strip
            next unless sub_raw.blank? || sub_raw == "[]"

            sub_def = sub_defs.find do |sd|
              sd.is_a?(Hash) && sd["order"].to_i == sub_q.sub_question_order.to_i && sd["text"].to_s.strip == sub_q.question_text.to_s.strip
            end

            if sub_def.blank?
              missing += 1
              next
            end

            sub_restored = answer_options_for.call(sub_def["options"])
            if sub_restored.blank?
              missing += 1
              next
            end

            sub_q.update!(answer_options: sub_restored)
            restored += 1
          end
        end
      end
    end

    puts "Restored answer_options for #{restored} question(s)."
    puts "Skipped (already had options): #{skipped} question(s)."
    puts "Missing template match/options: #{missing} question(s)."
  end
end
