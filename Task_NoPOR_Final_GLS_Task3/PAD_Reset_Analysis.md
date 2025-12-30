# SCL-180 Power-On Reset (POR) Analysis – Comprehensive Report

## Executive Summary

This document analyzes why **Power-On Reset (POR) is architecturally mandatory in SKY130** but **optional in SCL-180** for the Caravel chip design. The key difference lies in **pad-level interface requirements**: SKY130 I/O pads require explicit POR-driven enable signals, while SCL-180 pads operate independently without POR control pins.

---

## 1. Understanding Power-On Reset (POR) in SoC Design

### 1.1 What is Power-On Reset?

**Power-On Reset (POR)** is an on-chip circuit that:
- Detects when supply voltage (`VDD`) reaches a valid operating threshold
- Generates a clean reset signal (`porb_h`, `porb_l`) to initialize the design
- Prevents the chip from operating in an undefined state during power-up
- Provides timed sequencing for mixed-signal and I/O domains

**Key Characteristics:**
```
VDD Rising → Detect Threshold → Generate porb_h → Delay Timer → porb_h goes HIGH (inactive)
                                                    (prevents glitches during ramp)
```

### 1.2 Two Types of Reset in Digital Design

| Aspect | External Reset | Internal POR |
|--------|---|---|
| **Source** | External pin (resetb) from board | On-chip circuit |
| **Timing** | Controlled by external circuit | Automatic at power-up |
| **Advantage** | Works for any supply sequence | Reliable, doesn't depend on external circuit |
| **Disadvantage** | Requires external supervisor IC | More complex to implement |
| **Use Case** | Simple designs, external supervisor | High-reliability systems |

---

## 2. SCL-180 Reset Pad Architecture (Current Design)

### 2.1 The Active Reset Pad: `pc3d21`

In `rtl/chip_io.v`, the **actual reset pad instantiation** is:

```verilog
pc3d21 resetb_pad (
    .PAD(resetb),           // External pad pin
    .CIN(resetb_core_h)     // Output to core logic
);
```

**Critical Observation:** This pad has **only 2 pins**:
- `.PAD` – Physical I/O pad (connected to external reset pin)
- `.CIN` – Core input (drives internal reset net)

**What's Missing?**
- ❌ No `.ENABLE_H` pin (unlike SKY130)
- ❌ No `.ENABLE_VDDA_H` pin
- ❌ No POR control mechanism
- ❌ No power-good gating

**What This Means:**
The pad is a **simple input buffer** with no control logic. It directly buffers the external reset signal into the core.

### 2.2 How `pc3d21` is Different from SKY130 XRES

In the **original SKY130 design** (now commented out in `rtl/chip_io.v`):

```verilog
/* SKY130 XRES Reset Pad (COMMENTED OUT - NOT USED)
sky130_fd_io__top_xres4v2 resetb_pad (
    .PAD(resetb),
    .CIN(resetb_core_h),
    
    // POR-RELATED CONTROLS (not present in SCL-180 pc3d21)
    .ENABLE_H(porb_h),          // ← POR drives this enable
    .EN_VDDIO_SIG_H(porb_h),    // ← POR controls IO domain
    .INP_SEL_H(...),            // ← POR-driven input select
    .FILT_IN_H(...),            // ← POR-driven glitch filter
    .PULLUP_H(porb_h),          // ← POR controls pullup
    // ... many more POR-driven pins
);
*/
```

**Key Differences:**

| Feature | SKY130 XRES | SCL-180 pc3d21 |
|---------|---|---|
| **ENABLE_H pin** | ✅ Yes (drives POR) | ❌ No |
| **Glitch filter** | ✅ POR-controlled | ❌ Fixed internally |
| **Pullup control** | ✅ POR-driven | ❌ Fixed internally |
| **Input selector** | ✅ POR-selectable | ❌ Always active |
| **Power-up behavior** | Needs POR sequencing | Always available |
| **Complexity** | High (mixed-signal) | Low (simple buffer) |

**Why This Matters:**
- **SKY130:** The reset pad itself depends on POR to be functional
- **SCL-180:** The reset pad is always functional; no POR dependency

---

## 3. SCL-180 I/O Pad Ecosystem (Why POR Isn't Needed for Pads)

### 3.1 General GPIO Pad Wrappers in SCL-180

All SCL-180 pads used in this design are from `rtl/scl180_wrapper/`:

#### **pc3b03ed_wrapper** (Bidirectional GPIO)
```verilog
module pc3b03ed_wrapper(
    output IN,              // Data from external world
    input OUT,              // Data to external world
    input PAD,              // Physical pad
    input INPUT_DIS,        // Disable input buffer
    input OUT_EN_N,         // Output enable (active low)
    input [2:0] dm          // Drive mode (strength)
);

pc3b03ed pad(
    .CIN(IN),
    .OEN(output_EN_N),
    .RENB(pull_down_enb),
    .I(OUT),
    .PAD(PAD)
);
endmodule
```

**Control Pins Available:**
- `INPUT_DIS` – Disable input when not needed
- `OUT_EN_N` – Tri-state output enable
- `dm[2:0]` – Drive mode selection

**NOT Available:**
- ❌ `ENABLE_H` (POR-driven)
- ❌ `ENABLE_VDDA_H` (POR-driven)
- ❌ Any power-sequencing pins

#### **pc3d01_wrapper** (Input-Only Pad)
```verilog
module pc3d01_wrapper(
    output IN,
    input PAD
);
pc3d01 pad(.CIN(IN), .PAD(PAD));
endmodule
```

**This is the simplest pad:** Just an input buffer. No controls.

#### **pt3b02_wrapper** (Tristate Output Pad)
```verilog
module pt3b02_wrapper(
    output IN,
    inout PAD,
    input OE_N          // Output enable
);
pt3b02 pad(.CIN(IN), .OEN(OE_N), .I(), .PAD(PAD));
endmodule
```

**Only control:** Output enable (`OE_N`). No POR involvement.

### 3.2 What This Tells Us

**All SCL-180 pads used in this design:**
1. Have **no POR-driven enable pins**
2. Have **no power sequencing constraints**
3. Are **always ready** once VDD is stable
4. Manage internal level-shifting and ESD protection **independently**

**Contrast with SKY130 (from unused `rtl/pads.v`):**
```verilog
// SKY130 pads (NOT USED in this build, shown for reference)
.ENABLE_H(porb_h),              // ← POR controls
.ENABLE_INP_H(porb_h),          // ← POR controls
.ENABLE_VDDA_H(porb_h),         // ← POR controls
.ENABLE_VSWITCH_H(porb_h),      // ← POR controls
.ENABLE_VDDIO(porb_h),          // ← POR controls
```

These SKY130 macros **require** POR to function correctly, but they're **not instantiated in the SCL-180 build**.

---

## 4. Level Shifting and Voltage Domain Handling

### 4.1 SCL-180 Built-in Level Shifting

From `rtl/dummy_por.v`:

```verilog
// Comment from dummy_por.v:
// "since SCL180 has level-shifters already available in I/O pads"
assign porb_l = porb_h;
```

**What This Means:**

| Aspect | Implication |
|--------|---|
| **Where level shifting happens** | Inside the SCL-180 pad macro cells |
| **Not in RTL logic** | The dummy_por.v file just wires porb_h = porb_l |
| **Power domain handling** | Handled by pad internals, not by POR logic |
| **Design simplification** | Eliminates need for separate analog level shifters |

**Historical Context (SKY130):**
- SKY130 pads required explicit control of multiple voltage domains
- POR had to drive separate enable signals for each domain
- More complex, but necessary for that process technology

**SCL-180 Advantage:**
- Voltage domain management is **encapsulated in the pad macros**
- POR doesn't need to be aware of different voltage levels
- Simpler integration, fewer failure points

---

## 5. Why POR Was Mandatory in SKY130

### 5.1 SKY130 Reset Pad Dependency Chain

```
┌─────────────────────────────────────────┐
│  External VDD Ramps Up                  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  On-Chip POR Detects VDD Threshold      │
│  Generates porb_h (active low initially)│
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  porb_h → ENABLE_H on ALL pads          │
│  • GPIO pads not activated until now    │
│  • XRES pad not activated until now     │
│  • Prevents half-on state at power-up   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  porb_h → Reset Signal to Core Logic    │
│  (after internal glitch filtering)      │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  VDD Stable, Clocks Running             │
│  Core can now execute instructions      │
└─────────────────────────────────────────┘
```

### 5.2 Why This Sequence Was Critical for SKY130

**Problem Without POR-Driven Pad Enables:**

1. **Undefined Pad State During Power-Up**
   - If pads are "always on" during VDD ramp-up
   - I/O logic might partially activate
   - Could cause unexpected glitches, latch-up, or data corruption

2. **Reset Pad Glitch Issues**
   - XRES pad needs internal filtering to reject noise during power-up
   - Filtering is controlled by POR signal
   - Without POR control, filtering might not activate correctly

3. **Voltage Domain Sequencing**
   - Different pads operate at different voltage levels (VDDA, VDDIO, VDD)
   - Each domain needs independent enable sequencing
   - POR is the source of truth for "is power-up complete?"

4. **Undefined Digital State**
   - Without POR gating the reset path, reset might not reach all flip-flops
   - Inconsistent reset coverage could leave some logic initialized incorrectly

**Example SKY130 Issue Without POR-Driven Pads:**
```
Time: 0ns → VDD starts rising
Time: 0.5V VDD → Some pads partially activate (no ENABLE_H gating)
           → Input buffers start switching
           → Glitches propagate into core
           → Logic latches into undefined states
Time: 1V VDD → External reset pin asserted (correctly)
           → But pads ENABLE_H still not active (waiting for POR)
           → Reset doesn't propagate through pad enable logic
           → Core stays stuck in undefined state
```

**SCL-180 Doesn't Have This Problem:**
- All pads are always active (no ENABLE_H pins)
- Simple input buffer for reset
- No intermediate states during power-up
- Cleaner, more predictable behavior

---

## 6. Why POR is NOT Mandatory in SCL-180

### 6.1 SCL-180 Power-Up Sequence (Simplified)

```
┌─────────────────────────────────────────┐
│  External VDD Ramps Up                  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  SCL-180 Pads Automatically Available    │
│  (no ENABLE_H pins to wait for)         │
│  • pc3d21 reset buffer is ready         │
│  • All GPIO pads functional             │
│  • No sequencing dependency on POR      │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  External Reset (resetb) Asserted       │
│  (by external supervisor or RC circuit) │
│  • Drives pc3d21.PAD                    │
│  • Directly buffers to resetb_core_h    │
│  • No POR involvement needed            │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  Core Reset Logic Activated             │
│  • Async resets in flip-flops reset     │
│  • Housekeeping logic initializes       │
│  • Clock gating resets                  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  VDD Stable, Clocks Running             │
│  Core can now execute instructions      │
└─────────────────────────────────────────┘
```

### 6.2 Why SCL-180 Doesn't Need POR at the Pad Level

| Requirement | SKY130 Need | SCL-180 Need | Why? |
|---|---|---|---|
| **Pad enable sequencing** | ✅ CRITICAL | ❌ NOT NEEDED | SCL-180 pads have no ENABLE_H pins |
| **Reset pad glitch filtering** | ✅ POR-controlled | ✅ Fixed internally | SCL-180 filter doesn't need POR signal |
| **Voltage domain gating** | ✅ POR-driven | ❌ NOT NEEDED | SCL-180 handles levels inside pads |
| **Power-good detection** | ✅ POR provides it | ✅ External supervisor | Board circuit provides detection |
| **Digital reset sequencing** | ✅ POR orchestrates | ✅ Simple external reset | No complex sequencing in SCL-180 |

### 6.3 Evidence from the Code

**From `rtl/chip_io.v`:**
```verilog
// COMMENT IN CODE: Reset pad is simpler in SCL-180
// No POR enable pins exist to connect
pc3d21 resetb_pad (
    .PAD(resetb),
    .CIN(resetb_core_h)
    // Only 2 connections; no POR-related pins available
);
```

**From `rtl/dummy_por.v`:**
```verilog
// EXPLICIT COMMENT: "since SCL180 has level-shifters already 
// available in I/O pads, no POR-driven level shifting needed"
assign porb_l = porb_h;  // Just wires them together
```

**What This Code Tells Us:**
1. The designer explicitly chose NOT to connect POR to pads
2. SCL-180 pads don't provide the connection points anyway
3. Level shifting is internal to pads, not orchestrated by POR

---

## 7. Design Philosophy: External Reset Strategy for SCL-180

### 7.1 How SCL-180 Caravel Handles Reset

**Instead of relying on internal POR, this design uses:**

1. **External Reset Supervisor IC** (on the board)
   - Monitors VDD voltage
   - Holds `resetb` pin asserted during power-up
   - Releases `resetb` after VDD is stable
   - Example: TI TPS3808, Microchip MIC803

2. **RC Reset Circuit** (simple, passive)
   - Power-up capacitor + resistor on resetb pin
   - Generates timed reset pulse at power-on
   - Low cost but less reliable

3. **Testbench-Driven Reset** (for simulation)
   ```verilog
   // From hkspi_tb.v or similar
   initial begin
       RSTB = 1'b0;           // Assert reset
       # 100;
       RSTB = 1'b1;           // Release after 100ns
       // Now core is initialized
   end
   ```

### 7.2 Advantage of External Reset Strategy

| Aspect | Benefit |
|---|---|
| **Simplicity** | No analog POR circuit needed |
| **Reliability** | Board-level supervisor is proven, standard part |
| **Flexibility** | Can reset at any time (manual, watchdog, etc.) |
| **Cost** | Cheaper than on-chip analog POR |
| **Integration** | Works with standard ARM/SoC tools |

### 7.3 When This Strategy Works

✅ **Suitable for SCL-180 because:**
- Pads have no POR dependency
- Voltage domains are handled inside pads
- No complex pad-level sequencing
- Standard industry approach

❌ **Would NOT work for SKY130 because:**
- Pads require POR-driven ENABLE signals
- Would cause undefined pad states at power-up
- Could damage chip or cause latch-up

---

## 8. Direct Answers to Key Questions

### Q1: Does the reset pad require an internal enable?

**Answer: NO**

**Explanation:**
- The instantiated `pc3d21` pad has only `.PAD` and `.CIN` ports
- No `.ENABLE_H` or similar control pin exists
- The pad is always active once VDD is stable
- Comparison: SKY130 XRES required `.ENABLE_H(porb_h)`, but that's not used here

---

### Q2: Does the reset pad require POR-driven gating?

**Answer: NO**

**Explanation:**
- SCL-180 pads have no POR-related control pins
- Original SKY130 design needed `.ENABLE_H(porb_h)` on the reset pad
- SCL-180 replacement (`pc3d21`) doesn't expose this functionality
- Gating happens externally via board-level supervisor circuit

---

### Q3: Is the reset pin asynchronous?

**Answer: YES**

**Explanation:**
- `resetb_core_h` directly drives asynchronous reset inputs
- Example: housekeeping module async reset
- Example: clock-generation module async reset
- Design treats external reset as async, which is correct for reset pins

---

### Q4: Is the reset pin available immediately after VDD?

**Answer: YES (from RTL perspective)**

**Explanation:**
- No enable or gating in the RTL path
- `pc3d21` is a simple buffer: PAD → CIN
- Once VDD and external reset are valid, `resetb_core_h` is immediately active
- Note: Actual pad behavior (capacitance, slew rate) is inside the SCL-180 macro
- Design assumes external board circuit holds `resetb` asserted during power-ramp

---

### Q5: Are there documented power-up sequencing constraints that mandate a POR?

**Answer: NO (in SCL-180 context)**

**Explanation:**
- This repository contains NO PDK documentation explicitly requiring POR
- Code comments explicitly state: *"digital reset input due to lack of on-board POR"*
- Power-up sequencing is the **board circuit's responsibility**, not on-chip
- Comparison: SKY130 datasheets explicitly required POR-driven pad enables

---

### Q6: Why was POR mandatory in SKY130 but not in SCL-180?

**Answer: Pad Architecture Differences**

**Root Cause – SKY130:**
```
SKY130 XRES pad interface:
├── .ENABLE_H(porb_h)           ← POR controls if pad is active
├── .ENABLE_VDDA_H(porb_h)      ← POR gates VDDA domain
├── .FILT_IN_H(porb_h)          ← POR controls glitch filter
└── Many other POR-driven pins

↓ IMPLICATION:
Pad doesn't work correctly without POR-driven signals
→ POR is MANDATORY for correct pad operation
```

**Root Cause – SCL-180:**
```
SCL-180 pc3d21 pad interface:
├── .PAD(resetb)                ← External pin
└── .CIN(resetb_core_h)         ← To core

↓ IMPLICATION:
Pad works like a simple input buffer
→ POR is NOT needed for pad operation
→ Pads always available after VDD stable
```

**Full Comparison Table:**

| Factor | SKY130 (Requires POR) | SCL-180 (Optional POR) |
|---|---|---|
| **Pad ENABLE pins** | ✅ Present, POR-driven | ❌ Not present |
| **Glitch filter control** | ✅ POR-controlled | ✅ Fixed internally |
| **Voltage domain sequencing** | ✅ POR orchestrates | ✅ Pad macros handle |
| **Reset pad dependency** | ✅ XRES needs POR to function | ❌ pc3d21 independent |
| **Power-up sequence complexity** | High (analog POR + pad sequencing) | Low (external reset only) |
| **Risk of undefined state** | High if POR missing | Low (pads always ready) |

---

## 9. Practical Implementation Recommendations

### 9.1 For SCL-180 Caravel (No POR Required)

**Recommended Reset Strategy:**

```
External Board Circuit:
┌─────────────────────────────────────┐
│  VDD Monitor (e.g., TPS3808)        │
│  • Monitors VDD voltage             │
│  • Asserts RSTB when VDD < 4.5V     │
│  • Releases RSTB after ramp + delay │
└─────────────────────────────────────┘
        ↓
┌─────────────────────────────────────┐
│  SCL-180 Caravel Chip               │
│  • External RSTB → pc3d21 pad       │
│  • No internal POR needed           │
│  • Simpler, more reliable           │
└─────────────────────────────────────┘
```

**Configuration:**
- Remove dummy_por.v from implementation (optional, but clean)
- Keep external reset logic in testbench
- Board supervisor IC handles real hardware

---

### 9.2 For SKY130 Caravel (POR Required)

**Required Reset Strategy:**

```
On-Chip POR + External Reset (Complementary)
┌──────────────────┐
│  On-Chip POR     │
│  • Detects VDD   │
│  • Generates     │
│    porb_h signal │
│  • Drives pad    │
│    ENABLE_H pins │
└──────────────────┘
        ↓
All pads activate ONLY after POR
Prevents undefined states
```

---

## 10. Summary Table

| Aspect | SCL-180 | SKY130 |
|--------|---------|---------|
| **Reset Pad Type** | `pc3d21` (simple buffer) | `sky130_fd_io__top_xres4v2` (complex) |
| **Pad Enables** | None | `.ENABLE_H`, `.ENABLE_VDDA_H`, etc. (POR-driven) |
| **Glitch Filter** | Fixed internally | POR-controlled |
| **Level Shifting** | Inside pad macro | Requires POR orchestration |
| **POR Mandatory?** | ❌ NO | ✅ YES |
| **Reset Strategy** | External supervisor IC | On-chip POR circuit |
| **Power-Up Sequence** | Simple (external circuit) | Complex (POR timing) |
| **Reliability** | High (standard approach) | High (integrated solution) |
| **Integration Complexity** | Low | High |

---

## 11. Conclusion

**The SCL-180 design successfully removes the on-chip POR dependency by:**

1. Choosing I/O pad macros (pc3b03ed, pc3d01, pt3b02, pc3d21) that don't require POR-driven enable signals
2. Relying on pads' internal level-shifting capabilities instead of POR-controlled sequencing
3. Using an external reset supervisor IC (board-level) for power-up reset control
4. Simplifying the overall design while maintaining reliability

**This is a valid architectural choice for SCL-180 because the pad technology inherently provides:**
- Always-ready input buffers
- Integrated level shifting
- Independent voltage domain management

**Contrast with SKY130**, where pad architecture mandated on-chip POR due to:
- Explicitly exposed ENABLE pins requiring sequencing
- Mixed-signal nature requiring coordinated analog/digital control
- Voltage domain dependencies at the pad level

**Practical implication:** For GLS and simulation, `dummy_por.v` can be optionally removed because it's only a convenience for matching RTL and GL reset behavior—the actual reset functionality works through the external reset pin alone.

---

## References

- `rtl/chip_io.v` – reset pad instantiation and commented SKY130 XRES usage
- `rtl/scl180_wrapper/pc3b03ed_wrapper.v`, `pc3d01_wrapper.v`, `pt3b02_wrapper.v` – SCL-180 pad wrapper interfaces
- `rtl/dummy_por.v` – comment on SCL-180 pads having built-in level shifters
- `rtl/pads.v` – legacy SKY130 pad macros with POR-driven enables
- `rtl/caravel_netlists.v` – inclusion of `pc3d21.v` as the reset pad cell
- Testbench documentation and external reset control logic
