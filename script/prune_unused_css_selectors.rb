# frozen_string_literal: true

# Selector-level pruning of unused CSS.
#
# Reads tmp/unused_css_classes_report.txt and, for each CSS rule, removes selectors
# (within comma-separated selector lists) that reference at least one unused class.
# If all selectors are removed, the whole rule is removed.
#
# This is more aggressive than prune_unused_css_rules_delete_only.rb and will rewrite
# selector lists for affected rules (declarations remain unchanged).

require "pathname"
require "set"

ROOT = Pathname.new(__dir__).join("..").expand_path
REPORT_PATH = ROOT.join("tmp", "unused_css_classes_report.txt")
CSS_DIR = ROOT.join("app", "assets", "stylesheets")

CLASS_TOKEN_REGEX = /\.[a-zA-Z_][a-zA-Z0-9_-]*/

unless REPORT_PATH.exist?
  warn "Missing report at #{REPORT_PATH}. Run script/find_unused_css_classes.rb first."
  exit 1
end

unused_classes = Set.new
REPORT_PATH.read.each_line do |line|
  next unless line.start_with?("- ")
  class_name = line[2..].to_s.strip
  class_name = class_name.split.first.to_s
  next if class_name.empty?
  unused_classes << class_name
end

# Split selector list by commas while respecting (), [], and {}.
def split_selectors_with_spans(prelude)
  spans = []
  buf_start = 0
  paren = 0
  bracket = 0
  brace = 0
  in_string = nil

  i = 0
  while i < prelude.length
    ch = prelude[i]

    if in_string
      if ch == in_string
        in_string = nil
      elsif ch == "\\"
        i += 2
        next
      end
      i += 1
      next
    end

    if ch == '"' || ch == "'"
      in_string = ch
      i += 1
      next
    end

    case ch
    when "("
      paren += 1
    when ")"
      paren -= 1 if paren.positive?
    when "["
      bracket += 1
    when "]"
      bracket -= 1 if bracket.positive?
    when "{"
      brace += 1
    when "}"
      brace -= 1 if brace.positive?
    when ","
      if paren.zero? && bracket.zero? && brace.zero?
        spans << [buf_start, i]
        buf_start = i + 1
      end
    end

    i += 1
  end

  spans << [buf_start, prelude.length]
  spans
end

def selector_contains_unused_class?(selector, unused_classes)
  selector.scan(CLASS_TOKEN_REGEX).any? { |m| unused_classes.include?(m.delete_prefix(".")) }
end

# Returns [new_prelude_or_nil, removed_selector_count]
def prune_selector_list(prelude, unused_classes)
  spans = split_selectors_with_spans(prelude)

  kept = []
  removed = 0

  spans.each do |(s, e)|
    sel = prelude[s...e]
    if selector_contains_unused_class?(sel, unused_classes)
      removed += 1
    else
      kept << sel.strip
    end
  end

  return [nil, removed] if kept.empty?
  return [prelude, 0] if removed.zero?

  [kept.join(", "), removed]
end

# Returns [new_text, removed_rules, modified_rules, removed_selectors]
def prune_css(text, unused_classes)
  out = +""
  i = 0
  n = text.length
  removed_rules = 0
  modified_rules = 0
  removed_selectors = 0

  while i < n
    # Copy comments verbatim
    if i + 1 < n && text.getbyte(i) == 47 && text.getbyte(i + 1) == 42
      start = i
      i += 2
      while i + 1 < n && !(text.getbyte(i) == 42 && text.getbyte(i + 1) == 47)
        i += 1
      end
      i += 2 if i + 1 < n
      out << text[start...i]
      next
    end

    # End of current nesting
    if text.getbyte(i) == 125
      out << text[i..]
      break
    end

    prelude_start = i
    in_string = nil
    while i < n
      if i + 1 < n && text.getbyte(i) == 47 && text.getbyte(i + 1) == 42
        break
      end

      ch = text.getbyte(i)

      if in_string
        if ch == in_string
          in_string = nil
        elsif ch == 92
          i += 1
        end
        i += 1
        next
      end

      if ch == 34 || ch == 39
        in_string = ch
        i += 1
        next
      end

      break if ch == 123 || ch == 125
      i += 1
    end

    # Copy up to comment and continue
    if i + 1 < n && text.getbyte(i) == 47 && text.getbyte(i + 1) == 42
      out << text[prelude_start...i]
      next
    end

    # No block start => copy remainder
    if i >= n || text.getbyte(i) == 125
      out << text[prelude_start...i]
      next
    end

    prelude_end = i
    prelude = text[prelude_start...prelude_end]
    prelude_stripped = prelude.strip

    # Find matching block end
    i += 1
    block_start = i
    depth = 1
    in_string = nil

    while i < n && depth.positive?
      if i + 1 < n && text.getbyte(i) == 47 && text.getbyte(i + 1) == 42
        i += 2
        while i + 1 < n && !(text.getbyte(i) == 42 && text.getbyte(i + 1) == 47)
          i += 1
        end
        i += 2 if i + 1 < n
        next
      end

      ch = text.getbyte(i)

      if in_string
        if ch == in_string
          in_string = nil
        elsif ch == 92
          i += 1
        end
        i += 1
        next
      end

      if ch == 34 || ch == 39
        in_string = ch
        i += 1
        next
      end

      if ch == 123
        depth += 1
      elsif ch == 125
        depth -= 1
      end

      i += 1
    end

    block_end = i
    block_inner = text[block_start...(block_end - 1)]

    if prelude_stripped.start_with?("@")
      pruned_inner, rr, mr, rs = prune_css(block_inner, unused_classes)
      removed_rules += rr
      modified_rules += mr
      removed_selectors += rs

      # Keep original if inner unchanged
      if pruned_inner == block_inner
        out << text[prelude_start...block_end]
      else
        out << prelude
        out << "{"
        out << pruned_inner
        out << "}"
      end

      next
    end

    new_prelude, removed_in_rule = prune_selector_list(prelude_stripped, unused_classes)

    if new_prelude.nil?
      removed_rules += 1
      removed_selectors += removed_in_rule
      next
    end

    if removed_in_rule.zero?
      out << text[prelude_start...block_end]
      next
    end

    modified_rules += 1
    removed_selectors += removed_in_rule

    # Preserve leading whitespace before prelude, but rewrite prelude itself.
    leading = prelude[/\A\s*/].to_s
    out << leading
    out << new_prelude
    out << "{"
    out << block_inner
    out << "}"
  end

  [out, removed_rules, modified_rules, removed_selectors]
end

css_files = Dir.glob(CSS_DIR.join("**", "*.css").to_s).map { |p| Pathname.new(p) }

grand_removed_rules = 0
grand_modified_rules = 0
grand_removed_selectors = 0

css_files.each do |path|
  original = path.read
  pruned, removed_rules, modified_rules, removed_selectors = prune_css(original, unused_classes)

  next if pruned == original

  path.write(pruned)
  puts "Pruned #{path.relative_path_from(ROOT)}: removed_rules=#{removed_rules}, modified_rules=#{modified_rules}, removed_selectors=#{removed_selectors}"

  grand_removed_rules += removed_rules
  grand_modified_rules += modified_rules
  grand_removed_selectors += removed_selectors
end

puts "Done. removed_rules=#{grand_removed_rules}, modified_rules=#{grand_modified_rules}, removed_selectors=#{grand_removed_selectors}."
