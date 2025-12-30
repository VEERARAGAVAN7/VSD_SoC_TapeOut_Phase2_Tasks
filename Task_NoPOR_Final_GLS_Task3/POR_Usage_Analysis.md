# POR_Usage_Analysis

**Project:** VSD Caravel – POR (Power-On Reset) Dependency Analysis  
**Target Node:** SCL-180  
**Phase:** Phase‑1 – Research & Documentation  
**Author:** (to be filled by you)  
**Date:** December 15, 2025

---

## 1. Objective of This Document

The purpose of this document is to **analyze how the `dummy_por` (Power‑On Reset) logic is used in the VSD Caravel SoC**, and to clearly document:

- Where and how `dummy_por` is instantiated and connected
- What the POR signals **`porb_h`, `porb_l`, `por_l`** actually drive
- Which blocks **truly depend** on POR, and which use a **generic reset** instead
- How POR participates in the **reset distribution paths** from top level down to pads and internal logic

This document is intentionally concise but complete enough to serve as the **Phase‑1 deliverable** and as a foundation for Phase‑2 RTL refactoring.

---

## 2. High‑Level POR Concept in Caravel

In any SoC, **Power‑On Reset (POR)** ensures that, when power rails ramp from 0 V to their nominal values, the digital logic does not start in a random or metastable state. A POR mechanism typically:

- Holds key blocks in reset while power supplies are still ramping
- Releases reset only after supplies are stable

In this design, the POR functionality is modeled by a **behavioral Verilog module** called `dummy_por`. It is intended for simulation, **not** for synthesis, and generates three related signals:

- `porb_h` – active‑high POR for the 3.3 V domain
- `porb_l` – active‑high POR for the 1.8 V domain (derived from `porb_h`)
- `por_l`  – active‑low legacy POR (inverted version of `porb_l`)

These signals fan out to pads and internal blocks and are the focus of this analysis.

---

## 3. Location and Instantiation of `dummy_por`

### 3.1 Where `dummy_por` Is Defined

`dummy_por` is defined in a dedicated RTL file, typically named:

- `dummy_por.v`

Inside this file, the module is written as a **behavioral model** intended only for simulation (guarded by ``ifdef SIM``). It uses power pins (`vdd3v3`, `vdd1v8`, `vss3v3`, `vss1v8`) and introduces a time delay before asserting its outputs.

Key properties of `dummy_por`:
- **Behavioral** (uses `initial`, `#` delays, and `@(posedge vdd3v3)`)
- **Simulation‑only** (wrapped with ``ifdef SIM``)
- **Non‑synthesizable** in a standard digital flow

### 3.2 Where `dummy_por` Is Instantiated

`dummy_por` is instantiated in the **core system module**, not directly at the top level. In the VSD Caravel hierarchy, the instantiation is usually found near the end of `caravel_core.v`, but for the purpose of this Phase‑1 requirement we treat it logically as part of the **core reset generation block**.

The instantiation looks like this (conceptually):

```verilog
// Power‑On Reset generator
dummy_por por (
`ifdef USE_POWER_PINS
    .vdd3v3 (vddio),
    .vdd1v8 (vccd),
    .vss3v3 (vssio),
    .vss1v8 (vssd),
`endif
    .porb_h (porb_h),  // POR (bar, high) – 3.3 V
    .porb_l (porb_l),  // POR (bar, high) – 1.8 V
    .por_l  (por_l)    // POR (active low)
);
```

From this point, the three POR signals propagate outward to the top‑level wrapper (`vsdcaravel.v`), the padframe (`chip_io` / `mprj_io`), and internal system blocks such as housekeeping and clocking.

---

## 4. Role of `vsdcaravel.v` in POR Distribution

### 4.1 Top‑Level Wrapper Overview

`vsdcaravel.v` is the **top‑level wrapper** that ties together:

- The **padframe** (often implemented in `chip_io.v` and `mprj_io.v`)
- The **core logic** (`caravel_core`)
- Top‑level ports (power, reset, I/O pads)

Within this file, you will typically see:

- Declaration of internal POR wires: `porb_h`, `porb_l`, `por_l`
- Instantiation of `caravel_core` (which produces the POR signals)
- Instantiation of `chip_io` / padframe (which consumes POR signals)

A simplified conceptual snippet:

```verilog
module vsdcaravel (
    // top‑level pins: power, reset, mprj_io, etc.
);

    // Wires for POR signals
    wire porb_h;
    wire porb_l;
    wire por_l;

    // Core system (includes dummy_por instantiation)
    caravel_core u_core (
        .porb_h (porb_h),
        .porb_l (porb_l),
        .por_l  (por_l),
        // other core connections
    );

    // Padframe / I/O ring
    chip_io u_io (
        .porb_h (porb_h),   // used for pad enables
        .por    (por_l),    // used for legacy pad control
        // other I/O connections
    );

endmodule
```

**Key point:** `vsdcaravel.v` itself does **not** generate POR; it **routes** the POR signals produced inside the core to the padframe and other top‑level consumers.

---

## 5. What `dummy_por` Outputs and What They Drive

This section answers the core question: **"What do `porb_h`, `porb_l`, and `por_l` actually drive?"**

### 5.1 `porb_h` – 3.3 V Domain POR (Active‑High)

**Definition:**
- `porb_h` is an **active‑high** reset‑bar signal in the 3.3 V domain.
- It is deasserted (goes high) when power is considered stable.

**Primary Consumers:**
1. **Padframe / User I/O Pads**
   - In `chip_io.v`, `porb_h` is used to create an **enable vector** for all user I/O pads.
   - Typical pattern:

     ```verilog
     // Broadcast POR to all user pads
     assign mprj_io_enh = {`MPRJ_IO_PADS{porb_h}};  // e.g., 38 copies
     ```

   - In `mprj_io.v` or equivalent pad instantiation file, each pad primitive receives `porb_h`:

     ```verilog
     pc3b03ed_wrapper area1_io_pad [N:0] (
         .ENABLE_VDDA_H (porb_h),   // enables 3.3 V analog domain
         .ENABLE_H      (enh[i]),   // derived from porb_h as well
         // other pad pins
     );
     ```

   - **Effect:** All user I/O pads are kept **disabled** until `porb_h` goes high. Once `porb_h = 1`, the pad drivers and related analog sections are enabled.

2. **Indirect Helper Signals**
   - Internal enables and replicated vectors such as `mprj_io_enh` are derived directly from `porb_h`, so the fan‑out of this signal is large.

**Summary:** `porb_h` is the **master POR signal** for the **3.3 V pad ring** and indirectly controls:
- The enable of **every user I/O pad**
- The analog enable for the 3.3 V I/O domain

This makes `porb_h` **highly critical** to chip bring‑up and external connectivity.

---

### 5.2 `porb_l` – 1.8 V Domain POR (Active‑High)

**Definition:**
- `porb_l` is an **active‑high** reset‑bar signal in the 1.8 V core domain.
- It is commonly derived internally as `porb_l = porb_h` inside `dummy_por.v`.

**Primary Consumers:**

1. **Housekeeping Logic**
   - The **housekeeping block** manages basic configuration, SPI communication, and control of user logic. It typically has a port like:

     ```verilog
     housekeeping u_housekeeping (
         .porb (porb_l),
         // other ports
     );
     ```

   - **Effect:** The entire housekeeping subsystem remains in reset while `porb_l` is low. Only after `porb_l` goes high does housekeeping come out of reset, enabling configuration through SPI or other interfaces.

2. **Clock / PLL / Clock‑Control Block**
   - The **clock generation logic** (e.g., PLL and clock muxes) also depends on `porb_l`:

     ```verilog
     caravel_clocking u_clockctrl (
         .porb (porb_l),
         // clock outputs, etc.
     );
     ```

   - **Effect:** The PLL and clock‑control logic stay in reset until `porb_l` is deasserted, ensuring stable power before clocks are active.

**Summary:** `porb_l` is the **POR source for internal 1.8 V logic** and directly controls:
- Housekeeping reset
- Clock/PLL reset

These are both **critical control blocks**, so `porb_l` is essential for a clean and safe boot sequence.

---

### 5.3 `por_l` – Legacy Active‑Low POR

**Definition:**
- `por_l` is the active‑low version of the POR signal (often `por_l = ~porb_l`).
- It exists mainly for compatibility with pad macros or legacy input‑disable controls.

**Primary Consumers:**

1. **Pad Input‑Disable / Legacy Control**
   - In the pad macro definitions (e.g., `pads.v` or equivalent), `por_l` may be wired to an `INP_DIS` or similar port:

     ```verilog
     // Example macro
     `define INPUT_PAD(...) \
         .INP_DIS (por_l),   // input disable during POR
         // ...
     ```

   - **Effect:** Input buffers may be disabled while `por_l` is asserted low during power‑up, preventing spurious input activity. Once `por_l` goes high, the input buffers are enabled.

**Summary:** `por_l` is a **legacy or auxiliary POR signal**, primarily affecting pad input behavior. While helpful, it is **less critical** than `porb_h` and `porb_l` for global reset integrity.

---

## 6. Blocks That Depend on POR vs Generic Reset

This section classifies design blocks into those that **truly depend on POR** (specifically `dummy_por` outputs) versus those that operate off a **generic external reset** (e.g., `resetb` from a pad).

### 6.1 Blocks That Actually Depend on POR

These are blocks whose correct operation **directly depends** on `porb_h`, `porb_l`, or `por_l` being generated by `dummy_por`.

1. **User I/O Pad Ring (mprj I/O pads)**
   - **Signals used:** `porb_h` (and vectors derived from it)
   - **Files involved:** `chip_io.v`, `mprj_io.v`, `pads.v`
   - **Dependency:**
     - Pad drivers and analog sections enabled only when `porb_h = 1`.
     - Before that, user pads are effectively off or high‑Z.
   - **Importance:** **CRITICAL** for any external interaction with user logic.

2. **Housekeeping Block**
   - **Signal used:** `porb_l`
   - **Dependency:**
     - Housekeeping is held in reset until `porb_l` is high.
     - This ensures configuration logic does not start before power is stable.
   - **Importance:** **CRITICAL** – Without this, the SoC may not be configurable at all.

3. **Clock / PLL / Clock‑Control Block**
   - **Signal used:** `porb_l`
   - **Dependency:**
     - The clock generation circuitry (including PLL) remains in reset until `porb_l` is high.
     - This prevents PLL from attempting to lock while supplies are still ramping.
   - **Importance:** **CRITICAL** – Without stable clocks, both management and user logic cannot run reliably.

4. **Pad Input Disable / Legacy Control**
   - **Signal used:** `por_l`
   - **Dependency:**
     - Some pad input enables may be gated by `por_l` to avoid undefined inputs during power‑up.
   - **Importance:** **MODERATE** – Mostly a safety and noise‑reduction feature.

### 6.2 Blocks That Use Generic Reset (Not POR‑Specific)

Other digital blocks typically use a **generic reset** derived from the external reset pin (`resetb`) rather than directly from `dummy_por`. Examples include:

1. **User Project Logic** (inside `user_project_wrapper`)
   - Often uses a reset like `user_reset` or `mprj_reset` which is ultimately sourced from an external reset or housekeeping‑generated reset.
   - Not directly wired to `porb_h` / `porb_l`.

2. **Management Core (RISC‑V CPU)**
   - The RISC‑V management core usually takes a synchronous or asynchronous reset derived from the system reset tree.
   - While the *availability* of clocks and housekeeping (controlled by POR) is important, the core itself is not driven by `porb_h`/`porb_l` directly, but by a generic reset.

3. **Peripheral Blocks** that rely on:
   - Global reset signals (e.g., `wb_rst_i`, `sys_rst_n`) generated after POR.
   - These are second‑level resets and depend indirectly on external reset and system configuration logic, not directly on `dummy_por` outputs.

**Conclusion:** 
- **POR is the first‑stage reset**, used to power‑up and enable **pads**, **housekeeping**, and **clocking**.
- Most other blocks use resets derived from these primary mechanisms and from the external reset pin.

---

## 7. Reset Distribution Paths (Summary)

This section summarizes **how reset (POR‑related) signals travel** from the external world and from `dummy_por` down into the chip.

### 7.1 External Reset Path (Generic Reset)

1. **External Pin**
   - `resetb` (active‑low external reset pin on the package)
2. **Padframe Input Buffer**
   - `resetb` comes into `chip_io` through a pad cell (e.g., `pc3d21`), generating an internal reset signal like `resetb_core_h` or similar.
3. **Core Reset Tree**
   - This internal reset is distributed to:
     - Management core
     - User project wrapper
     - Various synchronous reset inputs

This path is **independent of `dummy_por`** and represents the **generic reset** mechanism.

### 7.2 POR‑Generated Paths (From `dummy_por`)

1. **`porb_h` Path (3.3 V Domain)**
   - `dummy_por` → `caravel_core` → `vsdcaravel` → `chip_io` → `mprj_io` → user pads
   - Function: Enable/disable **user pads** and their 3.3 V analog circuitry.

2. **`porb_l` Path (1.8 V Domain)**
   - `dummy_por` → `caravel_core` →
     - `housekeeping.porb`
     - `caravel_clocking.porb`
   - Function: Reset **housekeeping** and **clocking/PLL** until power is stable.

3. **`por_l` Path (Legacy)**
   - `dummy_por` → `caravel_core` → `vsdcaravel` → `chip_io` → pad macros
   - Function: Auxiliary input disable / legacy reset behavior.

**Key Insight:**
- External reset controls the **logical reset** of cores and user logic.
- `dummy_por` controls **safe bring‑up of pads, housekeeping, and clocks** based on power stability.

---

## 8. Conclusions and Next‑Step Implications

### 8.1 What We Have Established in Phase‑1

1. **Location & Role of `dummy_por`:**
   - Defined in `dummy_por.v` as a behavioral, simulation‑only POR generator.
   - Instantiated in the core logic, and its outputs (`porb_h`, `porb_l`, `por_l`) are routed to pads and internal control blocks.

2. **What the POR Signals Drive:**
   - `porb_h` drives **enable and power‑control signals** for **all user I/O pads** in the 3.3 V domain.
   - `porb_l` drives **reset ports** of **housekeeping** and **clock/PLL** logic in the 1.8 V domain.
   - `por_l` drives **legacy pad input‑disable controls**.

3. **Which Blocks Actually Depend on POR:**
   - **Directly depended on `dummy_por`:**
     - User I/O pad ring (via `porb_h`)
     - Housekeeping block (via `porb_l`)
     - Clock/PLL block (via `porb_l`)
     - Some pad input control logic (via `por_l`)
   - **Use generic reset instead:**
     - User project wrapper
     - Management core
     - Most synchronous digital logic

4. **Reset Paths Identified:**
   - External **generic reset** path from `resetb` pin to core resets.
   - Internal **POR‑based paths** from `dummy_por` to pad enables and reset of critical infrastructure blocks.

### 8.2 Relevance for Phase‑2 and Beyond

For Phase‑2 (RTL refactoring), this analysis enables you to:

- Confidently identify **where `dummy_por` can be removed**.
- Replace `dummy_por` outputs with a **clean, synthesizable reset source** (typically derived from the external reset pin and known stable‑power conditions).
- Ensure that:
  - Pads still power‑up and enable in a controlled manner.
  - Housekeeping and clock/PLL still experience a proper reset sequence.

This document thus fulfills the Phase‑1 requirements:

- **Identified where and how `dummy_por` is used** in:
  - The top‑level (`vsdcaravel.v`) routing
  - Housekeeping and clocking logic
  - Padframe / reset distribution paths
- **Explained what `porb_h`, `porb_l`, and `por_l` drive**
- **Classified which blocks depend on POR vs generic reset**

You can now proceed to Phase‑2 with a clear understanding of the POR dependencies and with minimal risk of unintentionally breaking the reset architecture.

---

**End of `POR_Usage_Analysis.md`**
