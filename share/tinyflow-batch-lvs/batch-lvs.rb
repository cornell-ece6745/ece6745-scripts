#batch-lvs.rb
#=========================================================================
# Ruby runner for batch LVS on stdcells.gds using KLayout
#=========================================================================
# Authors : Vayun Tiwari
# Date    : January 2026
# 
require 'fileutils'

input_file = File.absolute_path($input)
schematic_file = File.absolute_path($schematic)
output_dir = $output_dir || "lvs_results"
extraction_dir = $extraction_dir || "extraction_results"
lvs_deck = File.absolute_path($lvs || "scripts/lvs/batch-process/batch-cell-lvs.lylvs")
skip_cells = ["FILL"]

KLAYOUT = ENV['KLAYOUT'] || "klayout"

FileUtils.mkdir_p(output_dir)
FileUtils.mkdir_p(extraction_dir)

layout = RBA::Layout.new
layout.read(input_file)

cells = layout.each_cell.map(&:name).reject { |c| skip_cells.include?(c) }
puts "Found #{cells.length} cells: #{cells.join(', ')}"

results = { pass: [], fail: [], error: [] }

def parse_lvs_report(report_file)
  return nil unless File.exist?(report_file)
  
  content = File.read(report_file)
  
  # KLayout .lvsdb format starts with #%lvsdb-klayout
  unless content.start_with?("#%lvsdb-klayout")
    # Fallback for other formats
    if content.include?("Congratulations") || content.include?("netlists match")
      return { match: true, errors: [] }
    else
      return { match: false, errors: ["LVS comparison failed"] }
    end
  end
  
  errors = []
  
  # Extract the Z() cross-reference section
  z_section = content[/Z\((.*)\)/m, 1]
  
  unless z_section
    return { match: false, errors: ["No cross-reference section found"] }
  end
  
  # Parse mismatches from Z() section
  # Format: N(layout_id schematic_id status) where status=1 is match, 0 is mismatch
  
  # Net mismatches
  net_mismatches = z_section.scan(/N\((\d+) (\d+) 0\)/)
  net_mismatches.each do |layout_id, schem_id|
    errors << "Net mismatch: layout net #{layout_id} vs schematic net #{schem_id}"
  end
  
  # Device mismatches
  device_mismatches = z_section.scan(/D\((\d+) (\d+) 0\)/)
  device_mismatches.each do |layout_id, schem_id|
    errors << "Device mismatch: layout device #{layout_id} vs schematic device #{schem_id}"
  end
  
  # Pin mismatches
  pin_mismatches = z_section.scan(/P\((\d+) (\d+) 0\)/)
  pin_mismatches.each do |layout_id, schem_id|
    errors << "Pin mismatch: layout pin #{layout_id} vs schematic pin #{schem_id}"
  end
  
  # Check for unmatched items (where one side is 0)
  unmatched_layout_nets = z_section.scan(/N\((\d+) 0 0\)/)
  unmatched_layout_nets.each do |id|
    errors << "Extra net in layout: #{id[0]}"
  end
  
  unmatched_schem_nets = z_section.scan(/N\(0 (\d+) 0\)/)
  unmatched_schem_nets.each do |id|
    errors << "Missing net from schematic: #{id[0]}"
  end
  
  unmatched_layout_devices = z_section.scan(/D\((\d+) 0 0\)/)
  unmatched_layout_devices.each do |id|
    errors << "Extra device in layout: #{id[0]}"
  end
  
  unmatched_schem_devices = z_section.scan(/D\(0 (\d+) 0\)/)
  unmatched_schem_devices.each do |id|
    errors << "Missing device from schematic: #{id[0]}"
  end
  
  # Overall match status
  has_mismatch = z_section.include?(" 0)")
  
  { match: !has_mismatch, errors: errors }
end

cells.each do |cell_name|
  puts "\n#{'='*50}"
  puts "Running LVS on: #{cell_name}"
  puts '='*50
  
  report_file = File.absolute_path("#{output_dir}/#{cell_name}-lvslvs.lvsdb")
  target_file = File.absolute_path("#{extraction_dir}/#{cell_name}-rcx.sp")
  schematic_file = File.absolute_path("#{schematic_file}")
  
  # Check if schematic exists
  unless File.exist?(schematic_file)
    puts "SKIP - no schematic found: #{schematic_file}"
    results[:error] << { name: cell_name, reason: "no schematic" }
    next
  end
  
  cmd = [
    KLAYOUT, "-b", "-r", lvs_deck,
    "-rd", "input=#{input_file}",
    "-rd", "top=#{cell_name}",
    "-rd", "schematic=#{schematic_file}",
    "-rd", "report=#{report_file}",
    "-rd", "target=#{target_file}"
  ].join(" ")
  
  system(cmd)
  
  lvs_result = parse_lvs_report(report_file)
  
  if lvs_result.nil?
    puts "Failed - no report generated"
    results[:error] << { name: cell_name, reason: "no report" }
  elsif lvs_result[:match]
    puts "CLEAN"
    results[:pass] << cell_name
  else
    error_count = lvs_result[:errors].length
    puts "FAILED - #{error_count} issue(s) - check GUI LVS for details"
    results[:fail] << { name: cell_name, errors: lvs_result[:errors] }
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
    puts "  #{f[:name]} - #{f[:errors].length} issue(s) - check GUI LVS for details"
  end
end

if results[:error].any?
  puts "\nSkipped: #{results[:error].length}/#{cells.length}"
  results[:error].each do |e|
    puts "  - #{e[:name]}: #{e[:reason]}"
  end
end

exit(results[:fail].empty? && results[:error].empty? ? 0 : 1)