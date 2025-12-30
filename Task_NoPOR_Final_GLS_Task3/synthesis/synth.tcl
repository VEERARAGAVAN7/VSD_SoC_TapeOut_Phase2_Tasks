# ------------------------------------------------------------
# Load technology libraries
# ------------------------------------------------------------
read_db "/home/Synopsys/pdk/SCL_PDK_3/SCLPDK_V3.0_KIT/scl180/iopad/cio250/4M1L/liberty/tsl18cio250_min.db"
read_db "/home/Synopsys/pdk/SCL_PDK_3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/4M1IL/liberty/lib_flow_ff/tsl18fs120_scl_ff.db"

set target_library "/home/Synopsys/pdk/SCL_PDK_3/SCLPDK_V3.0_KIT/scl180/iopad/cio250/4M1L/liberty/tsl18cio250_min.db \
                    /home/Synopsys/pdk/SCL_PDK_3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/4M1IL/liberty/lib_flow_ff/tsl18fs120_scl_ff.db"

set link_library "* $target_library"

# ------------------------------------------------------------
# Paths and top module
# ------------------------------------------------------------
set root_dir "/home/veeram/vsdRiscvScl180_NoPoR"
set rtl_dir  "$root_dir/rtl"
set top_module "vsdcaravel"

set out_dir "$root_dir/synthesis/output"
set rpt_dir "$root_dir/synthesis/report"

# ------------------------------------------------------------
# Create blackbox stubs (RAM + POR) or we can create a manual stub file and attach the directory here
# ------------------------------------------------------------
set bb_file "$root_dir/synthesis/ram_por_blackbox_stubs.v"
set fp [open $bb_file w]

puts $fp "(* blackbox *) module RAM128(CLK, EN0, VGND, VPWR, A0, Di0, Do0, WE0);"
puts $fp "input CLK, EN0, VGND, VPWR;"
puts $fp "input [6:0] A0; input [31:0] Di0; input [3:0] WE0; output [31:0] Do0;"
puts $fp "endmodule"

puts $fp "(* blackbox *) module RAM256(VPWR, VGND, CLK, WE0, EN0, A0, Di0, Do0);"
puts $fp "inout VPWR, VGND; input CLK, EN0;"
puts $fp "input [7:0] A0; input [31:0] Di0; input [3:0] WE0; output [31:0] Do0;"
puts $fp "endmodule"


close $fp

# ------------------------------------------------------------
# Read RTL
# ------------------------------------------------------------
read_file $rtl_dir/defines.v -format verilog
read_file $bb_file -format verilog

set rtl_files [glob -nocomplain $rtl_dir/*.v]

#omiting this rtl files from readed entire rtl file 

set rtl_files [lremove $rtl_files \
    "$rtl_dir/RAM128.v" \
    "$rtl_dir/RAM256.v"  ]

read_file $rtl_files -define USE_POWER_PINS -format verilog

# ------------------------------------------------------------
# Elaborate & Link
# ------------------------------------------------------------
elaborate $top_module
link
uniquify

# ------------------------------------------------------------
# Mark blackboxes and dont_touch
# ------------------------------------------------------------
foreach blk {RAM128 RAM256} {
    if {[sizeof_collection [get_designs -quiet $blk]] > 0} {
        set_attribute [get_designs $blk] is_black_box true
        set_dont_touch [get_designs $blk]
    }
}

# ------------------------------------------------------------
# Compile (basic, safe)
# ------------------------------------------------------------
compile_ultra -topographical -effort high   
compile -incremental -map_effort high
# ------------------------------------------------------------
# Write outputs
# ------------------------------------------------------------
write -format verilog -hierarchy -output "$out_dir/vsdcaravel_synthesis.v"
write -format ddc     -hierarchy -output "$out_dir/vsdcaravel_synthesis.ddc"
write_sdc "$out_dir/vsdcaravel_synthesis.sdc"

# ------------------------------------------------------------
# Reports
# ------------------------------------------------------------
report_area       > "$rpt_dir/area.rpt"
report_power      > "$rpt_dir/power.rpt"
report_timing     > "$rpt_dir/timing.rpt"
report_qor        > "$rpt_dir/qor.rpt"
report_constraint -all_violators > "$rpt_dir/constraints.rpt"

# ------------------------------------------------------------
# End
# ------------------------------------------------------------
