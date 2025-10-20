#!/usr/bin/env ruby
require 'json'
path = File.join(__dir__, '..', 'coverage', '.resultset.json')
unless File.exist?(path)
  STDERR.puts "coverage/.resultset.json not found"
  exit 1
end
data = JSON.parse(File.read(path))
# SimpleCov may store multiple runs keyed by command name; use the most recent entry (last key)
root = data.keys.last
cov = data[root]['coverage']
rows = cov.map do |file, info|
  lines = info['lines'] || []
  total = lines.reject(&:nil?).length
  covered = lines.reject(&:nil?).count { |x| x && x > 0 }
  pct = total == 0 ? 100.0 : (covered.to_f / total * 100)
  [ pct, total, covered, file ]
end
rows.sort_by! { |r| r[0] }
puts "pct   total covered  file"
rows.each do |pct, total, covered, file|
  puts "%5.2f%% %5d %7d  %s" % [pct, total, covered, file]
end

# Print a short summary
total_lines = rows.map { |r| r[1] }.sum
total_covered = rows.map { |r| r[2] }.sum
overall = total_lines == 0 ? 100.0 : (total_covered.to_f / total_lines * 100)
puts "\nOverall coverage: #{'%.2f' % overall}% (#{total_covered} / #{total_lines})"
