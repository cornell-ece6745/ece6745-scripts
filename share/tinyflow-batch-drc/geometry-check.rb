#=========================================================================
# geometry-sanity.rb
#=========================================================================
# Simple malformed-geometry checker for KLayout batch flows
#=========================================================================

include RBA

input_path = File.absolute_path($input)
top_name   = $top

layout = Layout.new
layout.read(input_path)

top_cell = layout.cell(top_name)
if top_cell.nil?
  STDERR.puts "ERROR: top cell '#{top_name}' not found"
  exit 2
end

LAYERS_TO_CHECK = [
  [2,0], [3,0], [4,0], [5,0], [6,0], [7,0], [8,0], [9,0],
  [10,0], [11,0], [12,0], [13,0], [14,0], [15,0], [16,0],
  [17,0], [18,0], [99,0]
]

total_bad = 0

def report_bad(cell, layer, datatype, msg)
  puts "[BAD] cell=#{cell} L#{layer}/#{datatype} #{msg}"
end

# Walk cell definitions (top + all descendants) directly rather than via
# begin_shapes_rec, so each stored shape is visited exactly once regardless
# of how many times its parent cell is instantiated.
cells_to_check = [top_cell] + top_cell.called_cells.map { |ci| layout.cell(ci) }

layer_indices = LAYERS_TO_CHECK.map do |layer, datatype|
  li = layout.find_layer(LayerInfo.new(layer, datatype))
  li ? [layer, datatype, li] : nil
end.compact

cells_to_check.each do |cell|
  cell_name = cell.name

  layer_indices.each do |layer, datatype, li|
    cell.shapes(li).each do |shape|
      begin
        if shape.is_box?
          box = shape.box
          if box.width <= 0 || box.height <= 0
            report_bad(cell_name, layer, datatype, "zero-size box #{box}")
            total_bad += 1
          end

        elsif shape.is_path?
          path = shape.path

          if path.width <= 0
            report_bad(cell_name, layer, datatype, "path width <= 0 #{path.bbox}")
            total_bad += 1
          end

          begin
            poly = path.polygon
            if poly.area <= 0
              report_bad(cell_name, layer, datatype, "path -> zero-area polygon #{poly.bbox}")
              total_bad += 1
            end
          rescue => e
            report_bad(cell_name, layer, datatype, "path polygonization failed: #{e.message}")
            total_bad += 1
          end

        elsif shape.is_polygon?
          poly = shape.polygon

          if poly.area <= 0
            report_bad(cell_name, layer, datatype, "zero-area polygon #{poly.bbox}")
            total_bad += 1
          end

          pts = 0
          poly.each_point_hull { pts += 1 }
          if pts < 3
            report_bad(cell_name, layer, datatype, "invalid polygon (<3 hull pts) #{poly.bbox}")
            total_bad += 1
          end
        end

      rescue => e
        report_bad(cell_name, layer, datatype, "exception: #{e.message}")
        total_bad += 1
      end
    end
  end
end

if total_bad == 0
  puts "GEOMETRY SANITY CLEAN"
  exit 0
else
  puts "GEOMETRY SANITY FAILED: #{total_bad} issue(s)"
  exit 1
end