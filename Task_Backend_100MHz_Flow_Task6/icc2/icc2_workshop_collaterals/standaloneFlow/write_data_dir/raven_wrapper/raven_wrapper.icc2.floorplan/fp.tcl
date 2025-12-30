################################################################################
#
# Created by icc2 write_floorplan on Wed Dec 24 16:07:48 2025
#
################################################################################


set _dirName__0 [file dirname [file normalize [info script]]]

################################################################################
# Rows
################################################################################

remove_site_arrays -all

remove_site_rows -all

################################################################################
# Pins
################################################################################

set __pins [get_terminals -quiet]
if {[sizeof_collection $__pins] > 0} {
set __termShapes [get_shapes -of_objects [get_terminals * -quiet] -quiet]
if {[sizeof_collection $__termShapes] > 0} {
remove_shapes $__termShapes -force
}
set __termVias [get_vias -of_objects [get_terminals * -quiet] -quiet]
if {[sizeof_collection $__termVias] > 0} {
remove_vias $__termVias -force
}
set __termShapePatterns [get_shape_patterns -of_objects [get_terminals * -quiet] -quiet]
if {[sizeof_collection $__termShapePatterns] > 0} {
remove_shape_patterns $__termShapePatterns
}
}

################################################################################
# Net shapes and vias
################################################################################

set __netshapes [get_shapes -quiet]
if {[sizeof_collection $__netshapes] > 0} {
remove_shapes $__netshapes -force
}

set __netShapePatterns [get_shape_patterns -quiet]
if {[sizeof_collection $__netShapePatterns] > 0} {
remove_shape_patterns $__netShapePatterns
}

set __vias [get_vias -quiet]
if {[sizeof_collection $__vias] > 0} {
remove_vias $__vias -force
}

################################################################################
# Read DEF
################################################################################

read_def  ${_dirName__0}/floorplan.def.gz

################################################################################
# Voltage areas
################################################################################

remove_voltage_areas -all



################################################################################
# User attributes of voltage areas
################################################################################

################################################################################
# Site arrays
################################################################################

create_site_array -name unit_row -site unit -default -boundary { {300.0000 300.0000} {3288.0000 4888.0000} } -flip_first_row true -flip_alternate_row true -transparent false -direction horizontal -x_margin 0.0000 -y_margin 0.0000 -core_offset { 300.0000 300.0000 } -aligned true

################################################################################
# User attributes of site arrays
################################################################################


################################################################################
# Site rows cycle and offset attributes
################################################################################

################################################################################
# User attributes of site rows
################################################################################


################################################################################
# Keepouts
################################################################################


################################################################################
# User attributes of cells
################################################################################


################################################################################
# Bounds and user attributes of bound shapes
################################################################################

remove_bounds -all


################################################################################
# User attributes of bounds
################################################################################


################################################################################
# Pin guides
################################################################################

remove_pin_guides -all


################################################################################
# Route guides and their user attributes
################################################################################

remove_routing_guides -all



################################################################################
# Blockages
################################################################################

remove_routing_blockages -all -force

remove_placement_blockages -all -force

remove_pin_blockages -all

remove_shaping_blockages -all

################################################################################
# User attributes of blockages
################################################################################

################################################################################
# Module Boundaries
################################################################################

set hbCells [get_cells -quiet -filter hierarchy_type==boundary -hierarchical]
if [sizeof_collection $hbCells] {
   set_cell_hierarchy_type -type normal $hbCells
}


################################################################################
# User_shapes not written out by the def part
################################################################################

################################################################################
# Placment_Attractions
################################################################################

set _placementAttractions [get_placement_attractions * -quiet]
if [sizeof_collection $_placementAttractions] {
remove_placement_attractions $_placementAttractions -force
}

################################################################################
# User attributes of placement attractions
################################################################################


################################################################################
# Bump regions
################################################################################

remove_bump_regions -all

remove_pseudo_tsv_defs -all

remove_bump_regions -all

remove_bump_region_patterns -all

################################################################################
# set attributes of pseudo bumps
################################################################################

################################################################################
# set attributes of pseudo tsvs
################################################################################

################################################################################
# User attributes of bump region
################################################################################

################################################################################
# Bundles
################################################################################

set _bundles [get_bundles * -quiet]
if [sizeof_collection $_bundles] {
remove_bundles $_bundles
}


################################################################################
# User attributes of bundles
################################################################################


################################################################################
# I/O guides
################################################################################

remove_io_guides -all

create_io_guide -name default_guide_0 -side right -line { {3588.0000 5188.0000} 5188.0000 } -offset {0.0000 0.0000} -pad_cells { analog_out_sel_buf bg_ena_buf comp_ena_buf comp_in_buf comp_ninputsrc_buf comp_pinputsrc_buf ext_clk_buf ext_clk_sel_buf ext_reset_buf flash_clk_buf flash_csb_buf }
create_io_guide -name default_guide_1 -side left -line { {0.0000 0.0000} 5188.0000 } -offset {0.0000 0.0000} -pad_cells { flash_io_buf_0 flash_io_buf_1 flash_io_buf_2 flash_io_buf_3 gpio0 gpio1 gpio10 gpio11 gpio12 gpio13 gpio14 }
create_io_guide -name default_guide_2 -side top -line { {0.0000 5188.0000} 3588.0000 } -offset {0.0000 0.0000} -pad_cells { gpio15 gpio2 gpio3 gpio4 gpio5 gpio6 gpio7 gpio8 gpio9 irq_pin_buf opamp_bias_ena_buf }
create_io_guide -name default_guide_3 -side bottom -line { {3588.0000 0.0000} 3588.0000 } -offset {0.0000 0.0000} -pad_cells { opamp_ena_buf overtemp_buf overtemp_ena_buf pll_clk_buf rcosc_ena_buf rcosc_in_buf reset_buf ser_rx_buf ser_tx_buf spi_sck_buf trap_buf xtal_in_buf }

################################################################################
# User attributes of I/O guides
################################################################################


################################################################################
# Edit groups
################################################################################

remove_edit_groups -all -force


################################################################################
# User attributes of edit groups
################################################################################


################################################################################
# PG regions
################################################################################

remove_pg_regions -all


################################################################################
# User attributes of pg regions
################################################################################


################################################################################
# Routing corridors
################################################################################

remove_routing_corridors -all


################################################################################
# Routing directions
################################################################################

set_attribute -objects [get_layers metal1] -name routing_direction -value horizontal
set_attribute -objects [get_layers metal2] -name routing_direction -value vertical
set_attribute -objects [get_layers metal3] -name routing_direction -value horizontal
set_attribute -objects [get_layers metal4] -name routing_direction -value vertical
set_attribute -objects [get_layers metal5] -name routing_direction -value horizontal
set_attribute -objects [get_layers metal6] -name routing_direction -value vertical
set_attribute -objects [get_layers metal7] -name routing_direction -value horizontal
set_attribute -objects [get_layers metal8] -name routing_direction -value vertical
set_attribute -objects [get_layers metal9] -name routing_direction -value horizontal
set_attribute -objects [get_layers metal10] -name routing_direction -value vertical

################################################################################
# Tracks and their user attributes
################################################################################

remove_tracks -all

set track [create_track -layer metal1 -count 37057 -dir Y -space 0.1400 -coord 0.1200 -bbox {{0.0000 0.1200 } {3588.0000 5187.9600 }}]
set track [create_track -layer metal1 -count 25628 -dir X -space 0.1400 -coord 0.1200 -bbox {{0.1200 0.0000 } {3587.9000 5188.0000 }}]
set track [create_track -layer metal2 -count 27305 -dir Y -space 0.1900 -coord 0.1800 -bbox {{0.0000 0.1800 } {3588.0000 5187.9400 }}]
set track [create_track -layer metal2 -count 18884 -dir X -space 0.1900 -coord 0.1800 -bbox {{0.1800 0.0000 } {3587.9500 5188.0000 }}]
set track [create_track -layer metal3 -count 37057 -dir Y -space 0.1400 -coord 0.1200 -bbox {{0.0000 0.1200 } {3588.0000 5187.9600 }}]
set track [create_track -layer metal3 -count 25628 -dir X -space 0.1400 -coord 0.1200 -bbox {{0.1200 0.0000 } {3587.9000 5188.0000 }}]
set track [create_track -layer metal4 -count 18529 -dir Y -space 0.2800 -coord 0.1200 -bbox {{0.0000 0.1200 } {3588.0000 5187.9600 }}]
set track [create_track -layer metal4 -count 12814 -dir X -space 0.2800 -coord 0.1200 -bbox {{0.1200 0.0000 } {3587.7600 5188.0000 }}]
set track [create_track -layer metal5 -count 18529 -dir Y -space 0.2800 -coord 0.1200 -bbox {{0.0000 0.1200 } {3588.0000 5187.9600 }}]
set track [create_track -layer metal5 -count 12814 -dir X -space 0.2800 -coord 0.1200 -bbox {{0.1200 0.0000 } {3587.7600 5188.0000 }}]
set track [create_track -layer metal6 -count 18529 -dir Y -space 0.2800 -coord 0.1200 -bbox {{0.0000 0.1200 } {3588.0000 5187.9600 }}]
set track [create_track -layer metal6 -count 12814 -dir X -space 0.2800 -coord 0.1200 -bbox {{0.1200 0.0000 } {3587.7600 5188.0000 }}]
set track [create_track -layer metal7 -count 6486 -dir Y -space 0.8000 -coord 0.0000 -bbox {{0.0000 0.0000 } {3588.0000 5188.0000 }}]
set track [create_track -layer metal7 -count 4486 -dir X -space 0.8000 -coord 0.0000 -bbox {{0.0000 0.0000 } {3588.0000 5188.0000 }}]
set track [create_track -layer metal8 -count 6486 -dir Y -space 0.8000 -coord 0.0000 -bbox {{0.0000 0.0000 } {3588.0000 5188.0000 }}]
set track [create_track -layer metal8 -count 4486 -dir X -space 0.8000 -coord 0.0000 -bbox {{0.0000 0.0000 } {3588.0000 5188.0000 }}]
set track [create_track -layer metal9 -count 3243 -dir Y -space 1.6000 -coord 0.8000 -bbox {{0.0000 0.8000 } {3588.0000 5188.0000 }}]
set track [create_track -layer metal9 -count 2243 -dir X -space 1.6000 -coord 0.8000 -bbox {{0.8000 0.0000 } {3588.0000 5188.0000 }}]
set track [create_track -layer metal10 -count 3243 -dir Y -space 1.6000 -coord 0.8000 -bbox {{0.0000 0.8000 } {3588.0000 5188.0000 }}]
set track [create_track -layer metal10 -count 2243 -dir X -space 1.6000 -coord 0.8000 -bbox {{0.8000 0.0000 } {3588.0000 5188.0000 }}]

################################################################################
# Terminals/shapes/vias of ports with user attributes
################################################################################

################################################################################
# User attributes of ports
################################################################################


################################################################################
# Shapes and vias of net and their user attributes
################################################################################


################################################################################
# User attributes of routing rules
################################################################################


################################################################################
# User attributes of pins
################################################################################


################################################################################
# User attributes of nets
################################################################################


################################################################################
# Anchors
################################################################################

################################################################################
# User attributes of current block
################################################################################


