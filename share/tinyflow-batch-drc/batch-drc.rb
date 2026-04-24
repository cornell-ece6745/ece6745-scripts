#batch-drc.rb
#=========================================================================
# Ruby runner for batch DRC on stdcells.gds using KLayout
#=========================================================================
# Authors : Vayun Tiwari
# Date    : January 2026
#
require 'fileutils'
require 'rexml/document'
require 'shellwords'

input_file    = File.absolute_path($input)
output_dir    = $output_dir || "drc-results"
drc_deck      = File.absolute_path($drc || "scripts/drc/batch/cell.lydrc")
sanity_script = File.absolute_path(
  $sanity || "scripts/drc/batch/geometry-sanity.rb"
)
skip_cells    = [] # ["FILL"]

KLAYOUT = ENV['KLAYOUT'] || "klayout"

FileUtils.mkdir_p(output_dir)

layout = RBA::Layout.new
layout.read(input_file)
dbu = layout.dbu

LAYER_NAMES = {
  "2/0"   => "nwell",
  "3/0"   => "active",
  "4/0"   => "psel",
  "5/0"   => "nsel",
  "6/0"   => "poly",
  "7/0"   => "contact",
  "8/0"   => "metal1",
  "9/0"   => "via12",
  "10/0"  => "metal2",
  "11/0"  => "via23",
  "12/0"  => "metal3",
  "13/0"  => "via34",
  "14/0"  => "metal4",
  "15/0"  => "via45",
  "16/0"  => "metal5",
  "17/0"  => "via56",
  "18/0"  => "metal6",
  "99/0"  => "prboundary",
  "101/0" => "metal1_lbl",
  "998/0" => "htrack",
  "999/0" => "vtrack"
}

def count_violations(report_file)
  return nil unless File.exist?(report_file)

  doc = REXML::Document.new(File.read(report_file))

  descriptions = {}
  doc.elements.each("//categories/category") do |cat|
    name = cat.elements["name"]&.text
    desc = cat.elements["description"]&.text
    descriptions[name] = desc if name
  end

  categories = Hash.new(0)
  doc.elements.each("//items/item") do |item|
    cat = item.elements["category"]&.text&.gsub("'", "") || "unknown"
    categories[cat] += 1
  end

  by_rule = {}
  categories.each do |rule, count|
    desc = descriptions[rule]
    label = desc ? "#{rule}: #{desc}" : rule
    by_rule[label] = count
  end

  {
    total: categories.values.sum,
    by_rule: by_rule
  }
end

def run_cmd(cmd_parts, log_file: nil)
  cmd = cmd_parts.map { |x| Shellwords.escape(x.to_s) }.join(" ")

  ok =
    if log_file
      system("#{cmd} > #{Shellwords.escape(log_file)} 2>&1")
    else
      system(cmd)
    end

  [ok, $?.exitstatus]
end

def fmt_xy(v, dbu)
  x = v.to_f * dbu
  return x.round.to_s if (x - x.round).abs < 1e-9
  ("%0.3f" % x).sub(/\.?0+$/, "")
end

def format_sanity_line(line, dbu, layer_names)
  s = line.dup

  s.gsub!(/L(\d+\/\d+)/) do
    key = Regexp.last_match(1)
    name = layer_names[key] || "layer_#{key.tr('/', '_')}"
    "#{name} (#{key})"
  end

  s.gsub!(/\((-?\d+),(-?\d+);(-?\d+),(-?\d+)\)/) do
    x1 = fmt_xy(Regexp.last_match(1), dbu)
    y1 = fmt_xy(Regexp.last_match(2), dbu)
    x2 = fmt_xy(Regexp.last_match(3), dbu)
    y2 = fmt_xy(Regexp.last_match(4), dbu)
    "(#{x1},#{y1};#{x2},#{y2})"
  end

  s.gsub!(/\((-?\d+),(-?\d+)\)/) do
    x = fmt_xy(Regexp.last_match(1), dbu)
    y = fmt_xy(Regexp.last_match(2), dbu)
    "(#{x},#{y})"
  end

  s
end

top_cells = layout.top_cells.map(&:name)
if top_cells.length == 1
  cells = top_cells
  puts "Top cell: #{cells[0]}"
else
  cells = layout.each_cell.map(&:name).reject { |c| skip_cells.include?(c) }
  puts "No single top cell found, running on all #{cells.length} cells: #{cells.join(', ')}"
end

results = {
  pass: [],
  sanity_fail: [],
  drc_fail: [],
  tool_fail: []
}

cells.each do |cell_name|
  puts "\n#{'=' * 50}"
  puts "Running DRC on: #{cell_name}"
  puts "#{'=' * 50}"

  sanity_log  = File.absolute_path("#{output_dir}/#{cell_name}_sanity.log")
  report_file = File.absolute_path("#{output_dir}/#{cell_name}_drc.lyrdb")

  # Geometry sanity check
  sanity_cmd = [
    KLAYOUT, "-b", "-r", sanity_script,
    "-rd", "input=#{input_file}",
    "-rd", "top=#{cell_name}"
  ]

  sanity_ok, sanity_exit = run_cmd(sanity_cmd, log_file: sanity_log)
  sanity_output = File.exist?(sanity_log) ? File.read(sanity_log) : ""

  unless sanity_ok
    raw_bad = sanity_output.lines.select { |line| line.include?("[BAD]") }.map(&:strip)

    if raw_bad.empty?
      puts "Failed - geometry check tool error"
      results[:tool_fail] << {
        name: cell_name,
        stage: "sanity",
        errors: "exit #{sanity_exit}",
        details: sanity_output.lines.last(10).map(&:strip)
      }
    else
      bad_lines = raw_bad.map { |line| format_sanity_line(line, dbu, LAYER_NAMES) }
      puts "FAILED - #{bad_lines.length} malformed geometry issue(s):"
      bad_lines.first(20).each { |line| puts "    #{line}" }
      puts "    ... #{bad_lines.length - 20} more" if bad_lines.length > 20

      results[:sanity_fail] << {
        name: cell_name,
        errors: bad_lines.length,
        details: bad_lines
      }
    end

    next
  end

  # Normal DRC
  cmd = [
    KLAYOUT, "-b", "-r", drc_deck,
    "-rd", "input=#{input_file}",
    "-rd", "top=#{cell_name}",
    "-rd", "report=#{report_file}"
  ]

  drc_ok, drc_exit = run_cmd(cmd)
  violations = count_violations(report_file)

  if !drc_ok
    puts "Failed - DRC tool error"
    results[:tool_fail] << {
      name: cell_name,
      stage: "drc",
      errors: "exit #{drc_exit}",
      details: []
    }
  elsif violations.nil?
    puts "Failed - no report generated"
    results[:tool_fail] << {
      name: cell_name,
      stage: "drc",
      errors: "no report",
      details: []
    }
  elsif violations[:total] == 0
    puts "CLEAN"
    results[:pass] << cell_name
  else
    puts "FAILED - #{violations[:total]} violation(s):"
    violations[:by_rule].each do |rule, count|
      puts "    [#{count}] #{rule}"
    end
    results[:drc_fail] << {
      name: cell_name,
      errors: violations[:total],
      details: violations[:by_rule]
    }
  end
end

puts "\n#{'=' * 50}"
puts "SUMMARY"
puts "#{'=' * 50}"

puts "Clean: #{results[:pass].length}/#{cells.length}"
results[:pass].each { |c| puts "  #{c}" }

if results[:sanity_fail].any?
  puts "\nMalformed geometry failures: #{results[:sanity_fail].length}/#{cells.length}"
  results[:sanity_fail].each do |f|
    puts "  #{f[:name]}: #{f[:errors]} issue(s)"
    f[:details].first(20).each { |line| puts "      #{line}" }
    puts "      ... #{f[:details].length - 20} more" if f[:details].length > 20
  end
end

if results[:drc_fail].any?
  puts "\nDRC failures: #{results[:drc_fail].length}/#{cells.length}"
  results[:drc_fail].each do |f|
    puts "  #{f[:name]}: #{f[:errors]} violation(s)"
    f[:details].each do |rule, count|
      puts "      [#{count}] #{rule}"
    end
  end
end

if results[:tool_fail].any?
  puts "\nTool failures: #{results[:tool_fail].length}/#{cells.length}"
  results[:tool_fail].each do |f|
    puts "  #{f[:name]} (#{f[:stage]}): #{f[:errors]}"
    f[:details].each { |line| puts "      #{line}" }
  end
end

exit(
  results[:sanity_fail].empty? &&
  results[:drc_fail].empty? &&
  results[:tool_fail].empty? ? 0 : 1
)