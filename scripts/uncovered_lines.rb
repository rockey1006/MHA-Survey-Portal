#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

resultset_path = File.join(__dir__, "..", "coverage", ".resultset.json")
raise "coverage/.resultset.json not found" unless File.exist?(resultset_path)

needle = ARGV[0].to_s
raise "Usage: ruby scripts/uncovered_lines.rb <path-suffix>" if needle.empty?

data = JSON.parse(File.read(resultset_path))
root_key = data.keys.last
coverage = data.fetch(root_key).fetch("coverage")

file = coverage.keys.find { |path| path.end_with?(needle) }
raise "No coverage entry ends with: #{needle}" unless file

lines = coverage.fetch(file).fetch("lines")
uncovered = []
lines.each_with_index do |val, idx|
  next if val.nil?
  uncovered << (idx + 1) if val == 0
end

puts file
puts "uncovered: #{uncovered.size}"
puts uncovered.first(200).join(",")
