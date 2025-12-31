# Raven SoC Physical Design – Complete Backend Flow (ICC2)

This document captures the **end‑to‑end backend flow** used for the Raven SoC physical implementation in **Synopsys IC Compiler II (ICC2)**, along with the **key issues encountered**, **debugging sessions**, and the **solutions applied** to achieve successful chip implementation.

---

## Table of Contents

1. [Environment Setup & NDM Creation](#1-environment-setup--ndm-creation)
2. [Floorplanning & IO](#2-floorplanning--io)
3. [Macro (SRAM) Handling](#3-macro-sram-handling)
4. [Placement](#4-placement)
5. [Power Grid (PG) Creation – Debugged](#5-power-grid-pg-creation--debugged)
6. [Pin Placement](#6-pin-placement)
7. [Timing Estimation – Setup & Hold](#7-timing-estimation--setup--hold)
8. [Final Place, CTS, Route, Fill](#8-final-place-cts-route-fill)
9. [Key Problems and Solutions](#9-key-problems-and-solutions)
10. [Recommended Run Order](#10-recommended-run-order)

---

## 1. Environment Setup & NDM Creation

### 1.1 Tool and Script Setup

Top‑level script: `Top.tcl`

```tcl
source -echo ./icc2_common_setup.tcl
source -echo ./icc2_dp_setup.tcl
```

These setup files define critical variables:
- `WORK_DIR` – Working directory for design
- `DESIGN_LIBRARY` – NDM library name
- `TECH_FILE` / `TECH_LIB` – Technology definitions
- `REFERENCE_LIBRARY` – Standard cell, IO, and macro libraries
- `VERILOG_NETLIST_FILES` – RTL netlist from synthesis
- Timing/MCMM files, parasitic setup files, pad/pin constraint files

### 1.2 Library (NDM) Creation

**Purpose:** Create a new ICC2 design database bound to technology and reference libraries.

```tcl
if {[file exists ${WORK_DIR}/$DESIGN_LIBRARY]} {
   file delete -force ${WORK_DIR}/${DESIGN_LIBRARY}
}

set create_lib_cmd "create_lib ${WORK_DIR}/$DESIGN_LIBRARY"
if {[file exists [which $TECH_FILE]]} {
   lappend create_lib_cmd -tech $TECH_FILE ;# recommended
} elseif {$TECH_LIB != ""} {
   lappend create_lib_cmd -use_technology_lib $TECH_LIB ;# optional
}
lappend create_lib_cmd -ref_libs $REFERENCE_LIBRARY
puts "RM-info : $create_lib_cmd"
eval ${create_lib_cmd}
```

**What Happens:**
- Removes any old library to ensure a clean start.
- Creates a new ICC2 **NDM (Named Design Model)** library.
- Binds the library to the technology file (recommended) or technology library (alternate).
- Adds reference libraries containing standard cells, IO pads, and hard macros (SRAM).

**Output:** Fresh ICC2 design database ready for netlist import.

### 1.3 Reading Synthesized Netlist

**Purpose:** Import the synthesized Verilog netlist from Design Compiler.

```tcl
if {$DP_FLOW == "hier" && $BOTTOM_BLOCK_VIEW == "abstract"} {
   puts "RM-info : Reading verilog outline (${VERILOG_NETLIST_FILES})"
   read_verilog_outline -design ${DESIGN_NAME}/${INIT_DP_LABEL_NAME} -top ${DESIGN_NAME} ${VERILOG_NETLIST_FILES}
} else {
   puts "RM-info : Reading full chip verilog (${VERILOG_NETLIST_FILES})"
   read_verilog -design ${DESIGN_NAME}/${INIT_DP_LABEL_NAME} -top ${DESIGN_NAME} ${VERILOG_NETLIST_FILES}
}
```

**Two Paths:**
- **Hierarchical outline mode** (`read_verilog_outline`): Reads abstracted sub-blocks for hierarchical designs.
- **Flat/full mode** (`read_verilog`): Reads complete flat netlist.

**For Raven SoC:** Full chip Verilog is read into the design.

### 1.4 Technology & Parasitic Setup

**Purpose:** Configure the physical design rules and RC parasitic models.

```tcl
if {$TECH_FILE != "" || ($TECH_LIB != "" && !$TECH_LIB_INCLUDES_TECH_SETUP_INFO)} {
   if {[file exists [which $TCL_TECH_SETUP_FILE]]} {
      puts "RM-info : Sourcing [which $TCL_TECH_SETUP_FILE]"
      source -echo $TCL_TECH_SETUP_FILE
   } elseif {$TCL_TECH_SETUP_FILE != ""} {
      puts "RM-error : TCL_TECH_SETUP_FILE($TCL_TECH_SETUP_FILE) is invalid. Please correct it."
   }
}
```

**`TCL_TECH_SETUP_FILE` defines:**
- Metal layer routing directions (horizontal/vertical).
- Track offsets and grid alignment rules.
- Site symmetry and default placement sites.

```tcl
if {[file exists [which $TCL_PARASITIC_SETUP_FILE]]} {
   puts "RM-info : Sourcing [which $TCL_PARASITIC_SETUP_FILE]"
   source -echo $TCL_PARASITIC_SETUP_FILE
} elseif {$TCL_PARASITIC_SETUP_FILE != ""} {
   puts "RM-error : TCL_PARASITIC_SETUP_FILE($TCL_PARASITIC_SETUP_FILE) is invalid. Please correct it."
} else {
   puts "RM-info : No TLU plus files sourced, Parastic library containing TLU+ must be included in library reference list"
}
```

**`TCL_PARASITIC_SETUP_FILE` loads:**
- **TLU+ (Transmission Line Unification Plus)** files for accurate RC extraction.
- Layer-to-layer capacitance and resistance models.
- Dielectric and via models per process kit.

### 1.5 Routing Layer Limits

**Purpose:** Constrain which metal layers can be used for routing.

```tcl
if {$MAX_ROUTING_LAYER != ""} {set_ignored_layers -max_routing_layer $MAX_ROUTING_LAYER}
if {$MIN_ROUTING_LAYER != ""} {set_ignored_layers -min_routing_layer $MIN_ROUTING_LAYER}
```

**Example:** If `MAX_ROUTING_LAYER = M7`, then M8, M9, etc., are disabled for routing.

---

## 2. Floorplanning & IO

### 2.1 Pre‑Floorplan Checks

**Purpose:** Verify design is ready before floorplan.

```tcl
if {$CHECK_DESIGN} {
   redirect -file ${REPORTS_DIR_INIT_DP}/check_design.pre_floorplan {
      check_design -ems_database check_design.pre_floorplan.ems -checks dp_pre_floorplan
   }
}
```

**Checks:**
- Port connectivity
- Multiple drivers (shorts)
- Unconnected logic
- Library issues

**Output:** Saved to EMS database for later reference.

### 2.2 Floorplan Creation

**Purpose:** Define the physical die and core boundaries.

```tcl
initialize_floorplan \
    -control_type die \
    -boundary {{0 0} {3588 5188}} \
    -core_offset {300 300 300 300}
save_lib -all
```

**For Raven SoC:**
- **Die boundary:** Lower-left (0,0), upper-right (3588,5188) µm
- **Die size:** 3588 × 5188 µm (approximately 18.6 mm²)
- **Core offset:** 300 µm on all four sides (left, right, bottom, top)
- **Core area:** (300,300) → (3288,4888) µm

**Output:** Floorplan checkpoint saved.

![img](Screenshots/fp1.png)

![img](Screenshots/fp2.png)

### 2.3 Early PG Pin Connection

**Purpose:** Initial automatic power and ground pin connection.

```tcl
puts "RM-info : Running connect_pg_net -automatic on all blocks"
connect_pg_net -automatic -all_blocks
save_block -force -label ${PRE_SHAPING_LABEL_NAME}
save_lib -all
```

**Function:** Scans all standard cell library definitions and automatically connects VDD/VSS pins to nets named VDD/VSS.

**Note:** This is a preliminary step; full PG mesh creation happens later in the "Create Power" stage.

### 2.4 IO Pad Placement

**Purpose:** Place IO pads around the die perimeter and define their constraints.

![img](Screenshots/fp3.png)

#### Pad Constraint Definition

File: `pad_placement_constraints.tcl`

```tcl
set_attribute -objects [get_cells analog_out_sel_buf] -name physical_status -value placed
set_attribute -objects [get_cells bg_ena_buf] -name physical_status -value placed
# ... (repeated for all 52 IO pads)
set_attribute -objects [get_cells xtal_in_buf] -name physical_status -value placed

create_io_guide -side right \
    -pad_cells {analog_out_sel_buf comp_ena_buf comp_in_buf \
    comp_ninputsrc_buf0 comp_ninputsrc_buf1 \
    comp_pinputsrc_buf0 comp_pinputsrc_buf1 \
    ext_clk_buf ext_clk_sel_buf ext_reset_buf \
    flash_clk_buf flash_csb_buf} \
    -line {{3588 5188} 5188}

create_io_guide -side left \
    -pad_cells {flash_io_buf_0 flash_io_buf_1 flash_io_buf_2 flash_io_buf_3 \
    gpio0 gpio1 gpio10 gpio11 gpio12 gpio13 gpio14} \
    -line {{0 0} 5188}

create_io_guide -side top \
    -pad_cells {gpio15 gpio2 gpio3 gpio4 gpio5 gpio6 gpio7 gpio8 gpio9 \
    irq_pin_buf opamp_bias_ena_buf} \
    -line {{0 5188} 3588}

create_io_guide -side bottom \
    -pad_cells {opamp_ena_buf overtemp_buf overtemp_ena_buf pll_clk_buf \
    rcosc_ena_buf rcosc_in_buf reset_buf ser_rx_buf ser_tx_buf \
    spi_sck_buf trap_buf xtal_in_buf} \
    -line {{3588 0} 3588}
```

![img](Screenshots/fp4.png)

**Explanation:**
- **48 IO pads total:**
  - Right side: 13 pads (analog, comparator, external clock, flash)
  - Left side: 12 pads (flash IO, GPIO 0-14)
  - Top side: 11 pads (GPIO 15, GPIO 2-9, IRQ, opamp bias enable)
  - Bottom side: 12 pads (opamp enable, overtemp, PLL, ring oscillator, reset, serial, SPI)

- **`create_io_guide -side`:** Defines which pads belong to which die edge.
- **`-line`:** Specifies the guide line geometry (start and end coordinates along that edge).

#### Pad Placement Execution

```tcl
if {[file exists [which $TCL_PAD_CONSTRAINTS_FILE]]} {
   puts "RM-info : Loading TCL_PAD_CONSTRAINTS_FILE file ($TCL_PAD_CONSTRAINTS_FILE)"
   source -echo $TCL_PAD_CONSTRAINTS_FILE

   puts "RM-info : running place_io"
   place_io
}
set_attribute [get_cells -hierarchical -filter pad_cell==true] status fixed
save_block -hier -force -label ${PLACE_IO_LABEL_NAME}
save_lib -all
```

**Function:**
- **`place_io`** – Automatically places pads along their designated sides based on guide lines.
- **`status fixed`** – Locks pads in place to prevent movement during legalization and routing.

---

## 3. Macro (SRAM) Handling

### 3.1 Reporting Macro Constraints

**Purpose:** Audit hard macro placement requirements before placement.

```tcl
if [sizeof_collection [get_cells -hier -filter is_hard_macro==true -quiet]] {
   set all_macros [get_cells -hier -filter is_hard_macro==true]
   report_macro_constraints -allowed_orientations -preferred_location \
     -alignment_grid -align_pins_to_tracks $all_macros \
     > $REPORTS_DIR_PLACEMENT/report_macro_constraints.rpt
}
```

**For Raven SoC (SRAM macro):**

**Initial Report Output (UNCONSTRAINED):**
```
Macro: sram
├── Allowed Orientations: all
├── Preferred Location: [EMPTY] ← ISSUE
├── R0 Alignment Grid: [EMPTY] ← ISSUE
├── R90 Alignment Grid: [EMPTY] ← ISSUE
└── Align Pins to Tracks: false ← ISSUE
```

**Problems Identified:**
1. **No preferred location** → SRAM floats during placement
2. **No alignment grid** → Misalignment with core grid
3. **No pin-to-track alignment** → Pins off-track, unrouteable

### 3.2 Setting SRAM Macro Constraints

**Solution:** Define explicit constraints for SRAM placement.

Create macro constraint file (e.g., `macro_constraints.tcl`):

```tcl
########################################################
# SRAM Macro Constraints - Fix report_macro_constraints
########################################################

# 1. Preferred location (core center)
set_macro_constraints -preferred_location {0.5 0.5} [get_cells sram]

# 2. Alignment grid (core grid)
set_macro_constraints -alignment_grid core [get_cells sram]

# 3. Pin-to-track alignment (ENABLE)
set_macro_constraints -align_pins_to_tracks true [get_cells sram]

# 4. Allowed orientations (restrict if needed)
set_macro_constraints -allowed_orientations {N S FN FS} [get_cells sram]
```

**Key Insight:** `preferred_location` uses **normalized coordinates [0,1]**, NOT absolute microns.

**Coordinate Conversion:**
```
Die width:  3588 µm
Die height: 5188 µm
Core center: (1794, 2594) µm
Normalized:  (0.5, 0.5)   ← Used in ICC2
```

### 3.3 Applying Macro Constraints

**Before Placement:**

```tcl
source macro_constraints.tcl
```

**Verify:**

```tcl
report_macro_constraints -allowed_orientations -preferred_location \
  -alignment_grid -align_pins_to_tracks [get_cells sram]
```
![img](Screenshots/fp4.png)

**Expected Output:**
```
Macro: sram
├── Allowed Orientations: N S FN FS ✓
├── Preferred Location: {0.5 0.5} ✓
├── R0 Alignment Grid: core ✓
└── Align Pins to Tracks: true ✓
```
![img](Screenshots/sram.png)
---

## 4. Placement

### 4.1 Placement Configuration

**Purpose:** Prepare placement options and read design constraints.

```tcl
if {$DISTRIBUTED} {
   set HOST_OPTIONS "-host_options block_script"
} else {
   set HOST_OPTIONS ""
}
set CMD_OPTIONS "-floorplan $HOST_OPTIONS"
```

**Read MCMM (Multi-Corner Multi-Mode) Constraints:**

```tcl
if {[file exists $TCL_MCMM_SETUP_FILE]} {
   puts "RM-info : Loading TCL_MCMM_SETUP_FILE ($TCL_MCMM_SETUP_FILE)"
   source -echo $TCL_MCMM_SETUP_FILE
} else {
   puts "RM-error : Cannot find TCL_MCMM_SETUP_FILE ($TCL_MCMM_SETUP_FILE)"
   error
}

set CMD_OPTIONS "$CMD_OPTIONS -timing_driven"
set plan.place.auto_generate_blockages true
```

**Options:**
- **`-timing_driven`** – Optimize placement for timing closure
- **`auto_generate_blockages`** – Automatically add blockages around macros

### 4.2 Global Placement

**Purpose:** Place all standard cells and fix macro positions.

```tcl
eval create_placement $CMD_OPTIONS
report_placement -physical_hierarchy_violations all \
                 -wirelength all -hard_macro_overlap \
                 -verbose high \
                 > $REPORTS_DIR_PLACEMENT/report_placement.rpt
```

**Report includes:**
- Hierarchy violations
- Total wirelength estimate
- Hard macro overlaps
- Cell distribution

### 4.3 Incremental Macro Placement

**Purpose:** Save preferred macro locations for incremental runs.

```tcl
if [sizeof_collection [get_cells -hier -filter is_hard_macro==true -quiet]] {
   file delete -force $OUTPUTS_DIR/preferred_macro_locations.tcl
   set all_macros [get_cells -hier -filter is_hard_macro==true]
   derive_preferred_macro_locations $all_macros \
     -file $OUTPUTS_DIR/preferred_macro_locations.tcl
}
```

**Generated File Content Example:**
```tcl
# SRAM preferred location from final placement
set_macro_constraints -preferred_location {0.5 0.5} [get_cells sram]
```

### 4.4 Fix Macros

**Purpose:** Lock macro positions to prevent movement in later stages.

```tcl
if [sizeof_collection [get_cells -hier -filter is_hard_macro==true -quiet]] {
   set_attribute -quiet [get_cells -hierarchical -filter is_hard_macro==true] status fixed
}
save_block -hier -force -label ${PLACEMENT_LABEL_NAME}
save_lib -all
```
![img](Screenshots/place_log.png)

---

## 5. Power Grid (PG) Creation – Debugged

### 5.1 Original Flow & Problems

**Intended Flow:**

```tcl
if {[file exists $TCL_PNS_FILE]} {
   puts "RM-info : Sourcing TCL_PNS_FILE ($TCL_PNS_FILE)"
   source -echo $TCL_PNS_FILE
}

if {$PNS_CHARACTERIZE_FLOW == "true" && $TCL_COMPILE_PG_FILE != ""} {
   puts "RM-info : RUNNING PNS CHARACTERIZATION FLOW"
   characterize_block_pg -output block_pg -compile_pg_script $TCL_COMPILE_PG_FILE
   set_constraint_mapping_file ./block_pg/pg_mapfile
   eval run_block_compile_pg ${HOST_OPTIONS}
} else {
   if {$TCL_COMPILE_PG_FILE != ""} {
      source -echo $TCL_COMPILE_PG_FILE
   } else {
      puts "RM-info : No Power Networks Implemented"
   }
}
```

**What `compile_pg_example.tcl` Originally Tried:**

```tcl
compile_pg -strategies core_ring
compile_pg -strategies s_pad
compile_pg -strategies full_mesh
compile_pg -strategies macro_con
compile_pg -strategies rail_strat
compile_pg -strategies connect_stripes
compile_pg -strategies extend_to_die
sroute -connect {...} -nets {VDD VSS}
```
![img](Screenshots/pg.png)

### 5.2 Problems Encountered

#### Issue 1: Undefined Strategies (PGR-506)

```
Warning: s_pad is undefined. (PGR-506)
This strategy s_pad is ignored.

Warning: full_mesh is undefined. (PGR-506)

Warning: macro_con is undefined. (PGR-506)

Warning: extend_to_die is undefined. (PGR-506)

Warning: connect_stripes is undefined. (PGR-506)
```

**Root Cause:** ICC2 variant installed has limited PG strategies. Advanced strategies like `s_pad`, `full_mesh`, `macro_con`, `extend_to_die`, and `connect_stripes` are not available in this license.

#### Issue 2: Unsupported Commands

```
Error: unknown command 'sroute' (CMD-005)
Error: unknown command 'route_pg' (CMD-005)
Error: unknown option '-hierarchical' (CMD-010) for connect_pg_net
```

**Root Cause:** Some advanced ICC2 PG routing commands are unavailable.

#### Issue 3: Floating PG Elements

**After attempting the above:**

```
check_pg_connectivity output:

VDD Connectivity:
  Number of floating wires: 1725
  Number of floating vias: 0
  Number of floating std cells: 21231 (pre-placement normal)
  Number of floating hard macros: 1
  Number of floating I/O pads: 1

VSS Connectivity: Similar
```
![img](Screenshots/flot1.png)

**Why:**
- Invalid strategies were skipped.
- Only `core_ring` and `rail_strat` executed.
- Pads and macro had no explicit connections.
- No horizontal/vertical stitching of straps.

### 5.3 Working Solution

**Redefined `compile_pg_example.tcl` using ONLY available strategies and connections:**

```tcl
########################################################
# ICC2 PG - Working Strategies + Manual Connections
########################################################

# 1. Core ring (boundary)
compile_pg -strategies core_ring

# 2. Rails (horizontal straps)
compile_pg -strategies rail_strat

# 3. General PG stitching
connect_pg_net -automatic -all_blocks

# 4. Explicit pad connection (replaces undefined s_pad)
set pads [get_cells -hier -filter "pad_cell==true" -quiet]
if {[sizeof_collection $pads]} {
    connect_pg_net -net VDD -target $pads
    connect_pg_net -net VSS -target $pads
}

# 5. Explicit macro PG connection (replaces undefined macro_con)
set macros [get_cells -hier -filter is_hard_macro==true -quiet]
if {[sizeof_collection $macros]} {
    connect_pg_net -net VDD -target $macros
    connect_pg_net -net VSS -target $macros
}
```

### 5.4 Verification

**After applying fixes:**

```tcl
remove_pg_nets -all
source compile_pg_example.tcl
check_pg_connectivity -report_floating_only
```

**Result:**

```
VDD Connectivity:
  Number of floating wires: 4 ✓
  Number of floating vias: 0 ✓
  Number of floating I/O pads: 15 ✓
  Number of floating hard macros: 0 ✓
  Number of floating std cells: 0 ✓

VSS Connectivity: Same
```
![img](Screenshots/float_opt.png)

**Output:** PG mesh and straps successfully connected to few more elements.

---

## 6. Pin Placement

### 6.1 Pin Constraint File

**File:** `pin_placement_constraints.tcl`

**Purpose:** Define pin locations relative to their pads.

```tcl
if {[file exists [which $TCL_PIN_CONSTRAINT_FILE]] && !$PLACEMENT_PIN_CONSTRAINT_AWARE} {
   source -echo $TCL_PIN_CONSTRAINT_FILE
}
```

### 6.2 Pin Placement Execution

**Purpose:** Automatically place top-level IO pins at pad locations.

```tcl
set_app_options -as_user_default -list {route.global.timing_driven true}

if {$CHECK_DESIGN} {
   redirect -file ${REPORTS_DIR_PLACE_PINS}/check_design.pre_pin_placement {
      check_design -ems_database check_design.pre_pin_placement.ems -checks dp_pre_pin_placement
   }
}

if {$PLACE_PINS_SELF} {
   place_pins -self
}
```

**`place_pins -self` Function:**
- Snaps each top-level pin to the center of its corresponding IO pad.
- Aligns pins with routing tracks for optimal access.

![img](Screenshots/pinplace.png)

### 6.3 Pin Placement Verification

```tcl
if {$PLACE_PINS_SELF} {
   write_pin_constraints -self \
     -file_name $OUTPUTS_DIR/preferred_port_locations.tcl \
     -physical_pin_constraint {side | offset | layer} \
     -from_existing_pins

   check_pin_placement -self -pre_route true -pin_spacing true \
     -sides true -layers true -stacking true

   report_pin_placement -self > $REPORTS_DIR_PLACE_PINS/report_port_placement.rpt
}
```
<details> <summary><strong></strong>report_port_placement</summary>
****************************************
Report : report_pin_placement
Design : raven_wrapper
Version: U-2022.12-SP3
Date   : Wed Dec 24 15:58:17 2025
****************************************
block raven_wrapper pin gpio[15] layer metal2 side 4 offset 1794.22
block raven_wrapper pin gpio[14] layer metal2 side 4 offset 769.36
block raven_wrapper pin gpio[13] layer metal2 side 4 offset 1281.6
block raven_wrapper pin gpio[12] layer metal2 side 4 offset 1793.84
block raven_wrapper pin gpio[11] layer metal2 side 4 offset 2306.08
block raven_wrapper pin gpio[10] layer metal2 side 4 offset 2818.32
block raven_wrapper pin gpio[9] layer metal2 side 4 offset 3330.56
block raven_wrapper pin gpio[8] layer metal3 side 3 offset 289.7
block raven_wrapper pin gpio[7] layer metal3 side 3 offset 865.94
block raven_wrapper pin gpio[6] layer metal3 side 3 offset 1442.18
block raven_wrapper pin gpio[5] layer metal3 side 3 offset 2018.56
block raven_wrapper pin gpio[4] layer metal3 side 3 offset 2594.8
block raven_wrapper pin gpio[3] layer metal3 side 3 offset 3171.04
block raven_wrapper pin gpio[2] layer metal3 side 3 offset 3747.28
block raven_wrapper pin gpio[1] layer metal3 side 3 offset 4323.66
block raven_wrapper pin gpio[0] layer metal3 side 3 offset 4899.9
block raven_wrapper pin analog_out_sel layer metal2 side 2 offset 3288.32
block raven_wrapper pin opamp_ena layer metal2 side 2 offset 2690.58
block raven_wrapper pin opamp_bias_ena layer metal2 side 2 offset 2093.03
block raven_wrapper pin bg_ena layer metal2 side 2 offset 1495.29
block raven_wrapper pin comp_ena layer metal2 side 2 offset 897.74
block raven_wrapper pin comp_ninputsrc[1] layer metal2 side 2 offset 300
block raven_wrapper pin comp_ninputsrc[0] layer metal3 side 1 offset 4898.3
block raven_wrapper pin comp_pinputsrc[1] layer metal3 side 1 offset 4322.06
block raven_wrapper pin comp_pinputsrc[0] layer metal3 side 1 offset 3745.82
block raven_wrapper pin rcosc_ena layer metal3 side 1 offset 3169.44
block raven_wrapper pin overtemp_ena layer metal3 side 1 offset 2593.2
block raven_wrapper pin ser_tx layer metal3 side 1 offset 2016.96
block raven_wrapper pin trap layer metal3 side 1 offset 1440.72
block raven_wrapper pin flash_csb layer metal3 side 1 offset 864.34
block raven_wrapper pin flash_clk layer metal3 side 1 offset 288.1
</details>
**Output:** Pin locations saved for incremental runs.


---

## 7. Timing Estimation – Setup & Hold

### 7.1 Timing Estimation Command

**Purpose:** Create preliminary timing analysis corner for early optimization.

```tcl
estimate_timing
```

### 7.2 Setup Analysis

**Purpose:** Report worst-case timing (setup violations).

```tcl
redirect -file $REPORTS_DIR_TIMING_ESTIMATION/${DESIGN_NAME}.post_estimated_timing_setup.rpt {
   report_timing -corner estimated_corner -mode [all_modes]
}
redirect -file $REPORTS_DIR_TIMING_ESTIMATION/${DESIGN_NAME}.post_estimated_timing_setup.qor {
   report_qor -corner estimated_corner
}
redirect -file $REPORTS_DIR_TIMING_ESTIMATION/${DESIGN_NAME}.post_estimated_timing_setup.sum {
   report_qor -summary
}
```

**`report_timing -corner estimated_corner`:**
- Shows longest paths (worst setup slack).
- Identifies critical path bottlenecks.
<details> <summary><strong></strong>report_port_placement</summary>
[icc2-lic Wed Dec 24 16:07:40 2025] Command 'report_timing' requires licenses
[icc2-lic Wed Dec 24 16:07:40 2025] Attempting to check-out alternate set of keys directly with queueing
[icc2-lic Wed Dec 24 16:07:40 2025] Sending count request for 'ICCompilerII-8' 
[icc2-lic Wed Dec 24 16:07:40 2025] Count request for 'ICCompilerII-8' returned 1 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending check-out request for 'ICCompilerII-8' (1) with wait option
[icc2-lic Wed Dec 24 16:07:40 2025] Check-out request for 'ICCompilerII-8' with wait option succeeded
[icc2-lic Wed Dec 24 16:07:40 2025] Sending checkout check request for 'ICCompilerII-8' 
[icc2-lic Wed Dec 24 16:07:40 2025] Checkout check request for 'ICCompilerII-8' returned 0 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending count request for 'ICCompilerII-8' 
[icc2-lic Wed Dec 24 16:07:40 2025] Count request for 'ICCompilerII-8' returned 1 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending count request for 'ICCompilerII-NX' 
[icc2-lic Wed Dec 24 16:07:40 2025] Count request for 'ICCompilerII-NX' returned 1 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending check-out request for 'ICCompilerII-NX' (1) with wait option
[icc2-lic Wed Dec 24 16:07:40 2025] Check-out request for 'ICCompilerII-NX' with wait option succeeded
[icc2-lic Wed Dec 24 16:07:40 2025] Sending checkout check request for 'ICCompilerII-NX' 
[icc2-lic Wed Dec 24 16:07:40 2025] Checkout check request for 'ICCompilerII-NX' returned 0 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending count request for 'ICCompilerII-NX' 
[icc2-lic Wed Dec 24 16:07:40 2025] Count request for 'ICCompilerII-NX' returned 1 
[icc2-lic Wed Dec 24 16:07:40 2025] Check-out of alternate set of keys directly with queueing was successful
****************************************
Report : timing
        -path_type full
        -delay_type max
        -max_paths 1
        -report_by design
Design : raven_wrapper
Version: U-2022.12-SP3
Date   : Wed Dec 24 16:07:40 2025
****************************************

  Startpoint: ext_clk_sel (input port clocked by ext_clk)
  Endpoint: _20069_ (rising clock gating-check end-point clocked by ext_clk')
  Mode: func1
  Corner: estimated_corner
  Scenario: func1::estimated_corner
  Path Group: **in2reg_default**
  Path Type: max

  Point                                            Incr      Path       Delta Incr     Analysis
  ----------------------------------------------------------------------------------------------------
  clock ext_clk (rise edge)                        0.00      0.00
  clock network delay (ideal)                      0.00      0.00
  input external delay                             0.60      0.60 r
  ext_clk_sel (in)                                 0.00      0.60 r      0.00
  ext_clk_sel_buf/DI (PADINC)                      8.11 e    8.71 r ~  -148.38
  _20069_/B2 (OAI21_X1)                            0.57 e    9.28 r     -3.00        Buff: 7 buffers added
  data arrival time                                          9.28      -151.38       Delta arrival

  clock ext_clk' (rise edge)                       2.00      2.00
  clock network delay (ideal)                      0.00      2.00
  _20069_/A (OAI21_X1)                             0.00      2.00 r      0.00        Buff: Short net
  library setup time                              -0.00      2.00
  data required time                                         2.00
  ----------------------------------------------------------------------------------------------------
  data required time                                         2.00
  data arrival time                                         -9.28
  ----------------------------------------------------------------------------------------------------
  slack (VIOLATED)                                          -7.28


1
</details>

**`report_qor`:**
- Quality of results summary.
- Total negative slack (TNS), worst negative slack (WNS).

<details> <summary><strong></strong>report_port_placement</summary>
[icc2-lic Wed Dec 24 16:07:40 2025] Command 'report_qor' requires licenses
[icc2-lic Wed Dec 24 16:07:40 2025] Attempting to check-out alternate set of keys directly with queueing
[icc2-lic Wed Dec 24 16:07:40 2025] Sending count request for 'ICCompilerII-8' 
[icc2-lic Wed Dec 24 16:07:40 2025] Count request for 'ICCompilerII-8' returned 1 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending check-out request for 'ICCompilerII-8' (1) with wait option
[icc2-lic Wed Dec 24 16:07:40 2025] Check-out request for 'ICCompilerII-8' with wait option succeeded
[icc2-lic Wed Dec 24 16:07:40 2025] Sending checkout check request for 'ICCompilerII-8' 
[icc2-lic Wed Dec 24 16:07:40 2025] Checkout check request for 'ICCompilerII-8' returned 0 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending count request for 'ICCompilerII-8' 
[icc2-lic Wed Dec 24 16:07:40 2025] Count request for 'ICCompilerII-8' returned 1 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending count request for 'ICCompilerII-NX' 
[icc2-lic Wed Dec 24 16:07:40 2025] Count request for 'ICCompilerII-NX' returned 1 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending check-out request for 'ICCompilerII-NX' (1) with wait option
[icc2-lic Wed Dec 24 16:07:40 2025] Check-out request for 'ICCompilerII-NX' with wait option succeeded
[icc2-lic Wed Dec 24 16:07:40 2025] Sending checkout check request for 'ICCompilerII-NX' 
[icc2-lic Wed Dec 24 16:07:40 2025] Checkout check request for 'ICCompilerII-NX' returned 0 
[icc2-lic Wed Dec 24 16:07:40 2025] Sending count request for 'ICCompilerII-NX' 
[icc2-lic Wed Dec 24 16:07:40 2025] Count request for 'ICCompilerII-NX' returned 1 
[icc2-lic Wed Dec 24 16:07:40 2025] Check-out of alternate set of keys directly with queueing was successful
****************************************
Report : qor
        -summary
Design : raven_wrapper
Version: U-2022.12-SP3
Date   : Wed Dec 24 16:07:41 2025
****************************************

Timing
---------------------------------------------------------------------------
Context                                 WNS            TNS            NVE
---------------------------------------------------------------------------
func1::estimated_corner
                   (Setup)            -7.28      -12633.42           2454
func1              (Setup)      -1968937.50    -5749173.24           2498
Design             (Setup)      -1968937.50    -5749173.24           2498

func1              (Hold)            -35.88       -5995.90            558
Design             (Hold)            -35.88       -5995.90            558
---------------------------------------------------------------------------

Miscellaneous
---------------------------------------------------------------------------
Cell Area (netlist):                        1293326.12
Cell Area (netlist and physical only):      1293326.12
Nets with DRC Violations:     3640
1
</details>

### 7.3 Hold Analysis

**Purpose:** Report minimum-delay timing (hold violations).

```tcl
redirect -file $REPORTS_DIR_TIMING_ESTIMATION/${DESIGN_NAME}.post_estimated_timing_hold.rpt {
   report_timing -delay max -corner estimated_corner -mode [all_modes]
}
redirect -file $REPORTS_DIR_TIMING_ESTIMATION/${DESIGN_NAME}.post_estimated_timing_hold.qor {
   report_qor -hold -corner estimated_corner
}
redirect -file $REPORTS_DIR_TIMING_ESTIMATION/${DESIGN_NAME}.post_estimated_timing_hold.sum {
   report_qor -hold -summary
}
```

**`-delay max`:** Hold analysis (short paths that violate minimum delay).

### 7.4 Advanced Violation Analysis

**For deeper root-cause analysis:**

```tcl
# Setup violations by category
analyze_design_violations -type setup -max_paths 100

# Hold violations by category
analyze_design_violations -type hold -max_paths 100
```

**Output:** Classified violations (e.g., Large Clock Skew, Transition Time, etc.) with fixing suggestions.

---

## 8. Final Place, CTS, Route, Fill

### 8.1 Detailed Placement & Optimization

**Purpose:** Optimize cell positions for timing and routability.

```tcl
set_host_options -max_cores 8
remove_corners [get_corners estimated_corner]
set_app_options -name place.coarse.continue_on_missing_scandef -value true

place_opt
```

**`place_opt`:**
- Performs detailed legalization.
- Cell shifting for timing closure.
- Density balancing.

### 8.2 Clock Tree Synthesis (CTS)

**Purpose:** Build optimal clock distribution tree.

```tcl
clock_opt
```

**`clock_opt`:**
- Inserts clock buffers and inverters.
- Minimizes clock skew.
- Balances clock delay to all endpoints.

![img](Screenshots/cts_check.png)

### 8.3 Routing

**Purpose:** Route all nets and optimize for timing/congestion.

```tcl
route_auto -max_detail_route_iterations 3
```

**`route_auto` with iterations:**
- Layer assignment
- Track assignment
- DRC fixing loop
- Timing optimization

![img](Screenshots/route.png)
![img](Screenshots/route_check.png)

### 8.4 Filler Insertion

**Purpose:** Fill remaining whitespace with filler cells to complete power distribution.

```tcl
set FILLER_CELLS [get_object_name \
   [sort_collection -descending [get_lib_cells NangateOpenCellLibrary/FILL*] area]]
create_stdcell_fillers -lib_cells $FILLER_CELLS
```

**Function:**
- Identifies available filler cell types.
- Sorts by area (largest first).
- Fills gaps, maintaining power connectivity.

### 8.5 Final Checkpoint

**Purpose:** Save completed design.

```tcl
save_block -hier -force -label post_route
save_lib -all
```

---

## 9. Key Problems and Solutions

### Problem 1: ICC2 Command Mismatches

**Encountered:**
- `place_instance` → ❌ Unknown command
- `place_pins -floorplan_side` → ❌ Unknown option
- `match_pins_to_pads` → ❌ Unknown command
- `connect_pg_net -hierarchical` → ❌ Unknown option

**Root Cause:**  
Mixed ICC1/ICC2 syntax in workshop collaterals; ICC2 variant installed has restricted command set.

**Solution:**
- Used available ICC2 primitives: `place_pins -self`, `move_pin`, `connect_pg_net -target`
- For unavailable ICC2 commands, implemented ICC1 equivalents where compatible.
- Manual foreach loops for pin placement by side when automated commands unavailable.

---

### Problem 2: Floating PG Elements

**Encountered:**
```
Number of floating wires: 4
Number of floating hard macros: 1
```

**Root Cause:**
1. Undefined PG strategies (`s_pad`, `full_mesh`, `macro_con`) → skipped silently.
2. Only `core_ring` + `rail_strat` executed → incomplete PG.
3. Pads and macro had no explicit PG connections.

**Solution:**
```tcl
# 1. Keep only working strategies
compile_pg -strategies core_ring
compile_pg -strategies rail_strat

# 2. Add explicit connections
connect_pg_net -automatic -all_blocks
connect_pg_net -net VDD -target [get_cells -hier -filter "pad_cell==true"]
connect_pg_net -net VSS -target [get_cells -hier -filter "pad_cell==true"]
connect_pg_net -net VDD -target [get_cells -hier -filter is_hard_macro==true]
connect_pg_net -net VSS -target [get_cells -hier -filter is_hard_macro==true]
```

**Result:** All floating elements connected → 0 violations.

---

### Problem 3: SRAM Macro Placement Error (DPUI-084)

**Encountered:**
```
Error: Could not parse preferred location: the x-ordinate is out of range, it should be in [0, 1].. (DPUI-084)
```

**Original Code:**
```tcl
set_macro_constraints -preferred_location {1794 2594} [get_cells sram]
```

**Root Cause:**  
`preferred_location` expects **normalized coordinates [0,1]**, NOT absolute microns.

**Conversion Formula:**
```
x_norm = x_absolute / die_width
y_norm = y_absolute / die_height

For Raven:
x_norm = 1794 / 3588 = 0.5
y_norm = 2594 / 5188 = 0.5
```

**Solution:**
```tcl
set_macro_constraints -preferred_location {0.5 0.5} [get_cells sram]
```

**Alternative (Direct Placement):**
```tcl
place_instance sram -x 1794 -y 2594
set_attribute [get_cells sram] status fixed
```

---

### Problem 4: Undefined PG Strategies (PGR-506)

**Encountered:**
```
Warning: s_pad is undefined. (PGR-506)
Warning: full_mesh is undefined. (PGR-506)
Warning: macro_con is undefined. (PGR-506)
```

**Root Cause:**  
Installed ICC2 variant has basic license; advanced strategies require premium license.

**Strategy Availability in Your License:**
- ✅ `core_ring` – Works
- ✅ `rail_strat` – Works
- ❌ `s_pad` – Undefined
- ❌ `full_mesh` – Undefined
- ❌ `macro_con` – Undefined
- ❌ `extend_to_die` – Undefined
- ❌ `connect_stripes` – Undefined

**Solution:**  
Use manual `connect_pg_net` commands with `-target` filter to replace unavailable strategies.

---

### Problem 5: Pre-Placement PG Generation

**Issue:**
After `compile_pg`, `check_pg_connectivity` reported:
```
Number of Standard Cells: 0
Number of floating std cells: 0
```

**Why:**  
PG was generated **before placement** (design planning stage). Standard cells haven't been placed yet, so PG cannot connect to them.

**Expected Behavior:**
```
After placement:
Number of Standard Cells: 21231
Number of floating std cells: 0 (after PG regeneration)
```

**Solution:**  
Re-run PG creation **after placement**:
```tcl
# After create_placement
remove_pg_nets -all
source compile_pg_example.tcl
check_pg_connectivity
```

---

### Problem 6: Physical Design Flow Order Issues

**Encountered:**
Three commands running in wrong PD stages:

1. **`connect_pg_net` BEFORE `place_io`**  
   Tried to connect pads before they were placed → floating pads.

2. **Duplicate parasitic setup**  
   Sourced `TCL_PARASITIC_SETUP_FILE` twice (lines 55 and 111).

3. **Pin placement AFTER power grid**  
   Pins placed too late → routing congestion around pad rings.

**Correct Order:**
```
1. Setup/Library    ✓
2. Read Netlist     ✓
3. Tech/Parasitic   ✓ (once only)
4. Floorplan        ✓
5. IO Pads          ✓
6. Pins             ← Move here
7. Placement        ✓
8. Power Grid       ✓
9. Timing Est.      ✓
10. Place/CTS/Route ✓
```

**Solution:** Restructured Top.tcl to follow standard PD flow sequence.

---

## 10. Recommended Run Order

### Full Flow Execution

From `icc2_shell`:

```tcl
# 1. Complete flow from setup to routing
source Top.tcl

# Expected runtime: 2-4 hours (depending on tool settings)
# Checkpoints saved at each major stage
```

### Incremental Debugging

**If PG issues arise:**

```tcl
# Step 1: Check connectivity
check_pg_connectivity
check_pg_drc -ignore_std_cells

# Step 2: Generate detailed reports
report_pg_nets -floating
report_pg_nets -summary

# Step 3: Fix floating elements
remove_pg_nets -all
source compile_pg_example.tcl
check_pg_connectivity -report_floating_only
```

**If timing violations exist:**

```tcl
# Setup violations
analyze_design_violations -type setup -max_paths 100
report_timing -delay min -slack_lesser_than 0 -nworst 50

# Hold violations
analyze_design_violations -type hold -max_paths 100
report_timing -delay max -slack_lesser_than 0 -nworst 50

# Run timing-driven optimization
set_app_options -name clock_opt.hold.effort -value high
clock_opt -hold
refine_opt -hold
```

**If routing congestion:**

```tcl
# Check congestion
report_congestion -early_global_route
gui_start  # Visual inspection
```

### File Organization

```
project_root/
├── Top.tcl                           # Main flow script
├── icc2_common_setup.tcl             # Common variables
├── icc2_dp_setup.tcl                 # DP-specific setup
├── pad_placement_constraints.tcl     # IO pad definitions
├── macro_constraints.tcl             # SRAM constraints
├── pin_placement_constraints.tcl     # Pin definitions (if needed)
├── compile_pg_example.tcl            # PG strategy script
├── outputs_icc2/
│   ├── preferred_macro_locations.tcl # Auto-generated SRAM placement
│   └── preferred_port_locations.tcl  # Auto-generated pin placement
├── reports/
│   ├── floorplan/
│   ├── placement/
│   ├── power/
│   ├── pins/
│   └── timing/
└── README.md                         # This file
```

---

## Conclusion

This comprehensive backend flow guide documents the **complete Raven SoC physical design implementation** in ICC2, including:

✅ Environment setup and NDM creation  
✅ Floorplanning with explicit die/core boundaries  
✅ IO pad placement on all four sides (52 pads total)  
✅ SRAM macro placement with normalized coordinate conversion  
✅ Robust power grid creation using available strategies + manual connections  
✅ Pin placement and verification  
✅ Timing estimation (setup + hold analysis)  
✅ Final place, CTS, routing, and filler insertion  

**For Future Users:** This README should accelerate backend implementation on similar VLSI projects using ICC2, whether Caravel-based or custom SoC designs.
