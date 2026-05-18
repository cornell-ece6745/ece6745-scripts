#=========================================================================
# batch-lvs.rb
#=========================================================================
# Driver for running batch LVS with KLayout. Loaded by KLayout in batch
# mode via the wrapper tinyflow-batch-lvs:
#
#   klayout -b -r batch-lvs.rb \
#     -rd input=<layout.gds> -rd schematic=<netlist.sp> \
#     -rd lvs=<deck.lylvs> -rd output_dir=... -rd extraction_dir=...
#
# For each cell in the layout, spawns a KLayout subprocess to run the LVS
# deck, then parses the resulting .lvsdb report here. Also performs an
# out-of-band case-sensitive port-name check: KLayout's SPICE reader
# normalizes case before `compare` sees the names, so case mismatches
# between schematic .SUBCKT pins and layout labels are otherwise silent.
#
# Exit code: 0 if every cell matched, 1 if anything failed or was skipped.
#
# Authors : Vayun Tiwari and Parker Schless
# Date    : May 2026
#=========================================================================
require 'fileutils'

# KLayout exposes each `-rd key=value` command-line arg as a `$key` global.
input_file     = File.absolute_path($input)
schematic_file = File.absolute_path($schematic)
output_dir     = $output_dir || "lvs-results"
extraction_dir = $extraction_dir || "extraction_results"
lvs_deck       = File.absolute_path($lvs || "scripts/lvs/batch-process/batch-cell-lvs.lylvs")

# Cells with no schematic counterpart (e.g. pure-layout fill cells) - skipped
# in the multi-cell library mode below.
skip_cells = ["FILL"]

KLAYOUT = ENV['KLAYOUT'] || "klayout"

FileUtils.mkdir_p(output_dir)
FileUtils.mkdir_p(extraction_dir)

layout = RBA::Layout.new
layout.read(input_file)

# Two modes of operation:
#   - Single top cell (typical full-chip flow): run LVS just on that cell.
#   - Multi-cell library (e.g. stdcells.gds): run LVS on every cell except
#     those in `skip_cells`. Sub-cells get their own LVS run so each
#     standard cell is verified individually.
top_cells = layout.top_cells.map(&:name)
if top_cells.length == 1
  cells = top_cells
  puts "Top cell: #{cells[0]}"
else
  cells = layout.each_cell.map(&:name).reject { |c| skip_cells.include?(c) }
  puts "No single top cell found, running on all #{cells.length} cells: #{cells.join(', ')}"
end

# Per-cell outcomes: :pass = clean match, :fail = mismatches found,
# :error = could not run (missing schematic or no report produced).
results = { pass: [], fail: [], error: [] }

# Parse the ports declared on a .SUBCKT line for a given cell.
# Returns nil if the subckt isn't found, [] if it has no pins.
# SPICE keywords are case-insensitive; the cell name and pin names are matched
# as-stored so that case differences are preserved for the caller.
def parse_spice_subckt_pins(spice_file, cell_name)
  return nil unless File.exist?(spice_file)

  # Join SPICE continuation lines (lines beginning with '+')
  joined = []
  current = nil
  File.foreach(spice_file) do |raw|
    line = raw.chomp
    if line =~ /\A\s*\+\s*(.*)\z/
      current = "#{current} #{$1}" if current
    else
      joined << current if current
      current = line
    end
  end
  joined << current if current

  joined.each do |line|
    next unless line =~ /\A\s*\.subckt\s+(\S+)\s+(.*)\z/i
    next unless $1 == cell_name
    tokens = $2.split(/\s+/)
    return tokens.reject { |t| t.empty? || t.include?('=') || t.start_with?('*') || t.start_with?('$') }
  end
  nil
end

# Collect text strings on (layer_num, datatype) directly placed in a cell.
def collect_cell_labels(layout, cell_name, layer_num, datatype)
  cell = layout.cell(cell_name)
  return nil unless cell

  layer_idx = layout.find_layer(RBA::LayerInfo.new(layer_num, datatype))
  return [] unless layer_idx

  labels = []
  cell.each_shape(layer_idx) do |shape|
    labels << shape.text_string if shape.is_text?
  end
  labels.uniq
end

# Catch case mismatches that KLayout's SPICE reader hides via case normalization.
# Flag a SPICE pin only when an exact-case layout label is missing but a
# case-insensitive match exists - that pinpoints a true case mismatch and
# avoids double-reporting LVS-level missing-port errors.
def check_pin_case_match(spice_pins, layout_labels)
  errors = []
  spice_pins.each do |pin|
    next if layout_labels.include?(pin)
    lc = pin.downcase
    mismatch = layout_labels.find { |l| l.downcase == lc }
    errors << "Case mismatch: schematic pin '#{pin}' vs layout label '#{mismatch}'" if mismatch
  end
  errors
end

# Parse a KLayout LVS report and return { match: Boolean, errors: [String] }.
#
# Format reference: a .lvsdb file is an S-expression-style database. The
# Z(...) section is the cross-reference between layout and schematic, with
# records of the form:
#
#   N(layout_id schematic_id status)  - net pairing
#   D(layout_id schematic_id status)  - device pairing
#   P(layout_id schematic_id status)  - pin pairing
#
# `status` is 1 for a matched pair, 0 for a mismatch. An id of 0 on one
# side means that item exists on the other side only (extra in layout if
# schem_id == 0, missing from schematic if layout_id == 0).
def parse_lvs_report(report_file)
  return nil unless File.exist?(report_file)

  content = File.read(report_file)

  # Older KLayout (or hand-written) reports may be plain text rather than
  # the structured .lvsdb format. Fall back to a coarse string match so we
  # still produce a useful pass/fail.
  unless content.start_with?("#%lvsdb-klayout")
    if content.include?("Congratulations") || content.include?("netlists match")
      return { match: true, errors: [] }
    else
      return { match: false, errors: ["LVS comparison failed"] }
    end
  end

  errors = []

  # Extract the Z() cross-reference section (greedy match: it's the outermost
  # group in the file and may contain nested parens).
  z_section = content[/Z\((.*)\)/m, 1]

  unless z_section
    return { match: false, errors: ["No cross-reference section found"] }
  end

  # Mismatched pairings: both sides exist but didn't correspond.
  z_section.scan(/N\((\d+) (\d+) 0\)/).each do |layout_id, schem_id|
    errors << "Net mismatch: layout net #{layout_id} vs schematic net #{schem_id}"
  end
  z_section.scan(/D\((\d+) (\d+) 0\)/).each do |layout_id, schem_id|
    errors << "Device mismatch: layout device #{layout_id} vs schematic device #{schem_id}"
  end
  z_section.scan(/P\((\d+) (\d+) 0\)/).each do |layout_id, schem_id|
    errors << "Pin mismatch: layout pin #{layout_id} vs schematic pin #{schem_id}"
  end

  # Single-sided records: an id of 0 on one side means that item is unique
  # to the other side (extra-in-layout or missing-from-schematic).
  z_section.scan(/N\((\d+) 0 0\)/).each { |id| errors << "Extra net in layout: #{id[0]}" }
  z_section.scan(/N\(0 (\d+) 0\)/).each { |id| errors << "Missing net from schematic: #{id[0]}" }
  z_section.scan(/D\((\d+) 0 0\)/).each { |id| errors << "Extra device in layout: #{id[0]}" }
  z_section.scan(/D\(0 (\d+) 0\)/).each { |id| errors << "Missing device from schematic: #{id[0]}" }

  # Safety net: catches any record type with status=0 that our explicit
  # scans above missed (e.g. circuits, subcircuit instances, etc.).
  has_mismatch = z_section.include?(" 0)")

  { match: !has_mismatch, errors: errors }
end

# Run LVS once per cell. Each iteration spawns a fresh KLayout subprocess
# with the LVS deck and the cell name as the top - this keeps cells fully
# isolated (no shared netlist state) and matches how the deck is written.
cells.each do |cell_name|
  puts "\n#{'='*50}"
  puts "Running LVS on: #{cell_name}"
  puts '='*50

  report_file = File.absolute_path("#{output_dir}/#{cell_name}-lvslvs.lvsdb")
  target_file = File.absolute_path("#{extraction_dir}/#{cell_name}-rcx.sp")
  schematic_file = File.absolute_path("#{schematic_file}")

  unless File.exist?(schematic_file)
    puts "SKIP - no schematic found: #{schematic_file}"
    results[:error] << { name: cell_name, reason: "no schematic" }
    next
  end

  # KLayout doesn't expose a "set top cell" CLI flag, so we pass it as a
  # `-rd` global that the .lylvs deck reads via `$top`.
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

  # Out-of-band case-sensitive port-name check: KLayout's SPICE reader normalizes
  # case before `compare` sees the names, so case mismatches need to be caught here.
  spice_pins = parse_spice_subckt_pins(schematic_file, cell_name)
  layout_labels = collect_cell_labels(layout, cell_name, 101, 0) || []
  case_errors = spice_pins ? check_pin_case_match(spice_pins, layout_labels) : []
  if !case_errors.empty?
    lvs_result ||= { match: false, errors: [] }
    lvs_result[:match] = false
    lvs_result[:errors] = (lvs_result[:errors] || []) + case_errors
  end

  if lvs_result.nil?
    puts "Failed - no report generated"
    results[:error] << { name: cell_name, reason: "no report" }
  elsif lvs_result[:match]
    puts "CLEAN"
    results[:pass] << cell_name
  else
    error_count = lvs_result[:errors].length
    puts "FAILED - #{error_count} issue(s):"
    lvs_result[:errors].each { |err| puts "    - #{err}" }
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
    puts "  #{f[:name]} - #{f[:errors].length} issue(s):"
    f[:errors].each { |err| puts "    - #{err}" }
  end
end

if results[:error].any?
  puts "\nSkipped: #{results[:error].length}/#{cells.length}"
  results[:error].each do |e|
    puts "  - #{e[:name]}: #{e[:reason]}"
  end
end

# Non-zero on any failure or skip so CI / wrapper scripts can detect issues.
exit(results[:fail].empty? && results[:error].empty? ? 0 : 1)