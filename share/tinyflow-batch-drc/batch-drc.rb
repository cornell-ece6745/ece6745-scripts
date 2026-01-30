#batch-drc.rb
#=========================================================================
# Ruby runner for batch DRC on stdcells.gds using KLayout
#=========================================================================
# Authors : Vayun Tiwari
# Date    : January 2026
# 
require 'fileutils'
require 'rexml/document'

input_file = File.absolute_path($input)
output_dir = $output_dir || "drc-results"
drc_deck = File.absolute_path($drc || "scripts/drc/batch/cell.lydrc")
skip_cells = #["FILL"]

KLAYOUT = ENV['KLAYOUT'] || "klayout"

FileUtils.mkdir_p(output_dir)

layout = RBA::Layout.new
layout.read(input_file)

cells = layout.each_cell.map(&:name).reject { |c| skip_cells.include?(c) }
puts "Found #{cells.length} cells: #{cells.join(', ')}"

results = { pass: [], fail: [] }

def count_violations(report_file)
  return nil unless File.exist?(report_file)
  
  doc = REXML::Document.new(File.read(report_file))
  
  # Build category name -> description map
  descriptions = {}
  doc.elements.each("//categories/category") do |cat|
    name = cat.elements["name"]&.text
    desc = cat.elements["description"]&.text
    descriptions[name] = desc if name
  end
  
  # Count items by category
  categories = Hash.new(0)
  doc.elements.each("//items/item") do |item|
    cat = item.elements["category"]&.text&.gsub("'", "") || "unknown"
    categories[cat] += 1
  end
  
  total = categories.values.sum
  
  # Combine name with description
  by_rule = {}
  categories.each do |rule, count|
    desc = descriptions[rule]
    label = desc ? "#{rule}: #{desc}" : rule
    by_rule[label] = count
  end
  
  { total: total, by_rule: by_rule }
end

cells.each do |cell_name|
  puts "\n#{'='*50}"
  puts "Running DRC on: #{cell_name}"
  puts '='*50
  
  report_file = File.absolute_path("#{output_dir}/#{cell_name}_drc.lyrdb")
  
  cmd = [
    KLAYOUT, "-b", "-r", drc_deck,
    "-rd", "input=#{input_file}",
    "-rd", "top=#{cell_name}",
    "-rd", "report=#{report_file}"
  ].join(" ")
  
  system(cmd)
  
  violations = count_violations(report_file)
  
  if violations.nil?
    puts "Failed - no report generated"
    results[:fail] << { name: cell_name, errors: "no report", details: {} }
  elsif violations[:total] == 0
    puts "CLEAN"
    results[:pass] << cell_name
  else
    puts "FAILED - #{violations[:total]} violation(s):"
    violations[:by_rule].each do |rule, count|
      puts "    [#{count}] #{rule}"
    end
    results[:fail] << { name: cell_name, errors: violations[:total], details: violations[:by_rule] }
  end
end

puts "\n#{'='*50}"
puts "SUMMARY"
puts '='*50
puts "Clean: #{results[:pass].length}/#{cells.length}"
results[:pass].each { |c| puts "  #{c}" }

if results[:fail].any?
  puts "\nFailed: #{results[:fail].length}/#{cells.length}"
  results[:fail].each do |f|
    puts "  #{f[:name]}: #{f[:errors]} violation(s)"
    f[:details].each do |rule, count|
      puts "      [#{count}] #{rule}"
    end
  end
end

exit(results[:fail].empty? ? 0 : 1)
