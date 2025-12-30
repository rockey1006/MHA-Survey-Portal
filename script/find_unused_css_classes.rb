# frozen_string_literal: true

# Finds CSS class selectors defined in app/assets/stylesheets/**/*.css
# that are not referenced anywhere else in the repo (views/components/js/ruby/etc).
#
# Output:
# - Prints a summary to STDOUT
# - Writes tmp/unused_css_classes_report.txt

require "pathname"
require "set"

ROOT = Pathname.new(__dir__).join("..").expand_path
CSS_DIR = ROOT.join("app", "assets", "stylesheets")
REPORT_PATH = ROOT.join("tmp", "unused_css_classes_report.txt")

# Where we look for references (everything except stylesheets and typical build artifacts)
REFERENCE_ROOTS = [
  ROOT.join("app"),
  ROOT.join("components"),
  ROOT.join("config"),
  ROOT.join("lib"),
  ROOT.join("test"),
  ROOT.join("vendor")
].select(&:exist?)

EXCLUDE_DIRS = [
  ROOT.join("app", "assets", "stylesheets"),
  ROOT.join("app", "assets", "builds"),
  ROOT.join("node_modules"),
  ROOT.join("tmp"),
  ROOT.join("log")
].select(&:exist?)

TEXT_FILE_EXTENSIONS = Set.new(%w[
  .rb .rake .erb .haml .slim .js .jsx .ts .tsx .json .yml .yaml .md .html .css .scss
])

# Extract class names from CSS selectors.
# Conservative: only picks up tokens like `.foo-bar_123`.
CLASS_TOKEN_REGEX = /\.[a-zA-Z_][a-zA-Z0-9_-]*/

# Collect class tokens from selector preludes only (ignore declaration blocks).
def collect_class_tokens_from_css(text, classes_to_css_files, css_rel_path)
  i = 0
  n = text.length

  while i < n
    # Skip block comments
    if i + 1 < n && text.getbyte(i) == 47 && text.getbyte(i + 1) == 42
      i += 2
      while i + 1 < n && !(text.getbyte(i) == 42 && text.getbyte(i + 1) == 47)
        i += 1
      end
      i += 2 if i + 1 < n
      next
    end

    # Skip whitespace
    if text.getbyte(i) <= 32
      i += 1
      next
    end

    prelude_start = i
    in_string = nil

    # Read until a top-level '{' or ';'
    while i < n
      # comments inside prelude
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

      break if ch == 123 || ch == 59 || ch == 125
      i += 1
    end

    # Nothing meaningful left
    break if i >= n

    terminator = text.getbyte(i)
    prelude = text[prelude_start...i].to_s
    prelude_stripped = prelude.strip

    # Rule without block (e.g., @import ...;)
    if terminator == 59
      i += 1
      next
    end

    # End of a higher-level block
    if terminator == 125
      i += 1
      next
    end

    # At this point terminator is '{'
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
    block_inner = text[block_start...(block_end - 1)].to_s

    if prelude_stripped.start_with?("@")
      # Recurse for nested rules inside @media, @supports, etc.
      collect_class_tokens_from_css(block_inner, classes_to_css_files, css_rel_path)
      next
    end

    prelude_no_comments = prelude.gsub(%r{/\*.*?\*/}m, "")
    prelude_no_comments.scan(CLASS_TOKEN_REGEX).each do |match|
      class_name = match.delete_prefix(".")
      next if class_name.empty?
      # Ignore invalid/partial tokens like ".c-" that can arise from
      # comments/patterns (e.g., ".c-*" in documentation) or malformed selectors.
      # A trailing hyphen is not a valid unescaped class token in our codebase.
      next if class_name.end_with?("-")
      classes_to_css_files[class_name] << css_rel_path
    end
  end
end

# Match a class as a standalone token (avoid matching `btn` inside `btn-primary`).
# Allows boundaries of non-word/non-hyphen characters.
def token_regex(token)
  /(?<![A-Za-z0-9_-])#{Regexp.escape(token)}(?![A-Za-z0-9_-])/m
end

def text_file?(path)
  TEXT_FILE_EXTENSIONS.include?(path.extname.downcase)
end

def excluded?(path)
  EXCLUDE_DIRS.any? { |ex| path.to_s.start_with?(ex.to_s) }
end

css_files = Dir.glob(CSS_DIR.join("**", "*.css").to_s).map { |p| Pathname.new(p) }

classes_to_css_files = Hash.new { |h, k| h[k] = Set.new }

css_files.each do |css_path|
  content = css_path.read
  rel = css_path.relative_path_from(ROOT).to_s
  collect_class_tokens_from_css(content, classes_to_css_files, rel)
end

all_classes = classes_to_css_files.keys.sort

reference_files = []
REFERENCE_ROOTS.each do |root|
  Dir.glob(root.join("**", "*").to_s).each do |p|
    path = Pathname.new(p)
    next unless path.file?
    next if excluded?(path)
    next unless text_file?(path)
    reference_files << path
  end
end

# Preload file contents to avoid re-reading for every class.
# Keep memory reasonable by only loading text files.
reference_contents = {}
reference_files.each do |path|
  # Skip very large files to keep runtime safe; those are rarely templates.
  next if path.size > 2 * 1024 * 1024
  begin
    reference_contents[path.relative_path_from(ROOT).to_s] = path.read
  rescue StandardError
    # ignore unreadable files
  end
end

unused = []
used = []

all_classes.each_with_index do |class_name, idx|
  regex = token_regex(class_name)

  found = reference_contents.any? do |_rel, content|
    content.match?(regex)
  end

  if found
    used << class_name
  else
    unused << class_name
  end

  if (idx + 1) % 500 == 0
    warn "Scanned #{idx + 1}/#{all_classes.size} classes..."
  end
end

lines = []
lines << "Unused CSS class selectors report"
lines << "Generated at: #{Time.now}"
lines << "Root: #{ROOT}"
lines << ""
lines << "CSS files scanned: #{css_files.size}"
lines << "Reference files scanned: #{reference_contents.size}"
lines << "Total unique class selectors found in CSS: #{all_classes.size}"
lines << "Used classes (found in repo outside CSS): #{used.size}"
lines << "Unused classes (no references found): #{unused.size}"
lines << ""

lines << "Unused classes:"
unused.sort.each do |class_name|
  files = classes_to_css_files[class_name].to_a.sort
  lines << "- #{class_name}    (defined in: #{files.join(", ")})"
end

REPORT_PATH.dirname.mkpath
REPORT_PATH.write(lines.join("\n") + "\n")

puts "Wrote: #{REPORT_PATH.relative_path_from(ROOT)}"
puts "Unused classes: #{unused.size} / #{all_classes.size}"
