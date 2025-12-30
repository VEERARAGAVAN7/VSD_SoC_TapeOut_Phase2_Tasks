# External Reset Strategy in SCL-180
## Justification for a POR-Free Architecture

---

## Executive Summary

This document provides a design sign-off level justification for **removing on-chip Power-On Reset (POR) circuitry** in SCL-180 ASIC designs and **relying exclusively on an external reset via I/O pads**. The proposed approach leverages the proven robustness of SCL-180 pad Schmitt triggers, eliminates analog design risk, removes unverifiable RTL-based POR logic, and aligns with industry practice across 180 nm and 130 nm processes. The decision is backed by process-characterized pad behavior, formalized reset synchronization, and a clear risk-mitigation strategy.

---

## 1. POR as an Analog Problem

### 1.1 Inherent Analog Complexity

Conventional on-chip POR circuits are fundamentally **analog supervision circuits**, typically built from:

- Bandgap reference generators
- Comparators monitoring supply ramps
- RC delay networks

These introduce hard-to-control sensitivities:

#### Process Variation

- **MOS threshold variation**: ±100–200 mV
- **Capacitor tolerance**: ±10–20%
- **Resistor tolerance**: ±10–30%

#### Temperature Drift

- Bandgap references drifting by ±20–50 mV from −40°C to +125°C

#### Supply Dependence

- Sensitivity to power ramp rate
- Susceptibility to brown-out events
- Response to supply noise and ringing

#### Verification Burden

- Requires exhaustive PVT characterization
- Behavior varies with ramp shape and system-level power sequencing
- Corner coverage in SPICE rarely matches real board conditions

### 1.2 Sign-Off Implication

Because POR behavior depends on continuous parameters (voltages, slopes, temperature), it **cannot be exhaustively validated using digital flows alone**. Guaranteeing correct operation across all combinations of process, voltage, temperature, ramp slope, and noise is impractical in a digital-centric ASIC flow.

**Conclusion:**  
On-chip POR is an **analog design and verification problem**. For a digital SoC targeting SCL-180, this burden should be avoided and delegated to external circuitry and proven pad behavior instead of bespoke analog IP.

---

## 2. Why RTL-Based POR Is Unsafe

### 2.1 Metastability and Reset Domain Crossing

When POR is implemented purely in RTL (e.g., counters or timers that generate an internal reset), the reset behavior becomes **synchronous logic pretending to solve an inherently asynchronous problem**:

#### Asynchronous Reset Release

During power-up, internal reset signals deassert at arbitrary phases relative to each clock domain. This directly risks **reset recovery and removal violations**.

#### Multiple Clock Domains

A single POR net cannot be simultaneously synchronous to all clocks. At least one domain will see reset deasserted off-edge, violating setup/hold and recovery/removal timing.

#### Metastability Invisibility

RTL and gate-level digital simulations do not model analog metastability behavior inside flip-flops. A design can "pass" simulation while still having non-zero metastability risk in silicon.

#### Post-Silicon Exposure

Failures may only appear under specific voltage/temperature/process conditions and rare reset timing alignments, making debug extremely hard and field failures possible.

### 2.2 Verification Gap

Static timing analysis can **flag reset recovery/removal violations**, but:

- It cannot compute a meaningful **probability** of metastability
- It cannot show whether a metastable event will propagate to observable failure
- It does not model analog behavior of the metastable region

Therefore, a purely RTL-driven POR solution carries **unquantified reliability risk** that cannot be closed with standard STA + simulation sign-off.

**Conclusion:**  
RTL-based or "digital" POR is **not a safe replacement** for a well-defined external reset architecture and must be avoided in production-quality designs.

---

## 3. SCL-180 Pads as a Safe External Reset Source

### 3.1 Pad-Level Architecture

SCL-180 I/O pads intended for reset input include:

#### ESD Network

- Dual-diode or clamp structures for ≥2–3 kV HBM protection

#### Schmitt Trigger Input Stage

- Provides hysteresis and noise immunity at the pad

#### Well-Characterized Input Thresholds

- Typical values:
  - VTH− ≈ 0.7–0.85 V
  - VTH+ ≈ 2.4–2.55 V
- Hysteresis window: ~1.5–1.8 V

#### High Input Impedance

- Leakage currents on the order of 100 nA
- Allows simple RC networks without significant loading

These blocks are **standard library cells**, not custom analog IP, and are backed by foundry qualification.

### 3.2 Multi-Corner Characterization

SCL-180 pad cells are:

- Characterized across process corners (SS, TT, FF)
- Verified at ±10% supply variation
- Qualified from −40°C to +125°C
- Shipped with Liberty/SDF timing models for sign-off

The result is a **fully specified digital boundary**:

- The pad converts an arbitrary external waveform into a **clean digital 0/1** using Schmitt behavior
- The ASIC team **inherits** this characterization; no new analog development is required

**Conclusion:**  
SCL-180 reset pads provide a **stable, characterized, and production-proven** interface for external reset, eliminating the need for an on-chip POR macro.

---

## 4. External Reset Implementation Strategy

### 4.1 Recommended Board-Level Circuit

A simple RC network and pushbutton/reset source suffice:

```
Reset Button / External Source
    |
    +──[ R: 10–100 kΩ ]──+
                         |
                      [ C: 0.1 µF ]
                         |
                        GND

Node after RC → SCL-180 reset pad (Schmitt input)
```

### 4.2 Debounce and Filtering

With R = 10 kΩ and C = 0.1 µF:

#### Time Constant

τ = R · C ≈ 1 ms

#### Settling Time

≈10·τ ≈ 10 ms, sufficient to absorb typical mechanical switch bounce (10–50 ms worst-case)

#### Component Tolerances

- Resistor: 1%
- Capacitor: 5–10%

No precision analog matching is required because the pad's Schmitt hysteresis (≈1.5–1.8 V) provides ample noise margin.

### 4.3 On-Chip Reset Synchronization

Once the pad delivers a clean digital reset signal (e.g., 0 V/3.3 V), internal reset distribution proceeds via **standard synchronizers**:

#### Synchronizer Architecture

- Per-clock-domain triple-flop synchronizer (per Cliff Cummings' recommendations)

#### Input Characteristics

The synchronizer input is already:

- Debounced (RC network)
- Hysteresis-filtered (Schmitt trigger)
- Slowly changing relative to clock (10–100 ms scale vs ns clock periods)

#### Benefits

This allows:

- **Formal metastability analysis** on the synchronizer
- **Static timing** of reset recovery/removal at all synchronous elements
- Quantifiable probability of failure (often <10−12 per cycle), acceptable for ASIC production

**Key Point:**  
The **combination** of Schmitt input, RC filtering, and flip-flop synchronizers converts an uncontrolled analog problem into a **fully digital, verifiable reset architecture**.

---

## 5. Risk Analysis and Mitigation

### 5.1 Risk–Mitigation Matrix

| Risk | Mitigation Mechanism |
|------|----------------------|
| Reset button stuck low | Firmware watchdog triggers alternate reset; user-visible status LED |
| Noise or spikes on reset line | RC network (1–10 ms time constant) + Schmitt hysteresis |
| ESD-induced pad damage | Foundry-qualified ESD structures; standard handling procedures |
| Reset signal stuck high (no reset) | Multiple reset sources: button, JTAG, watchdog |
| Synchronizer metastability | Triple-flop synchronizers; formal/analytical MTBF estimation |
| Excessive reset propagation delay | Pad + synchronizer delay included in STA and timing budgets |

### 5.2 System-Level Safety Nets

#### Watchdog Timer

- Monitors software progress
- Can assert internal reset if firmware hangs
- Provides recovery path independent of user reset interactions

#### Multiple Reset Sources

- Manual pushbutton
- JTAG or debug interface reset
- Watchdog-triggered reset

Ensures **no single point of reset failure** at system level.

---

## 6. Industry Precedent: SKY130 vs SCL-180

### 6.1 SKY130 Experience

The open-source **SkyWater SKY130** process (130 nm) provides a strong reference:

- No standard, foundry-qualified POR macro is provided
- Designs **rely on external reset** through Schmitt-trigger pads
- The community uses:
  - Pad-based reset
  - Triple-flop synchronizers
  - Formal verification of reset distribution
- Thousands of tape-outs on SKY130 have successfully adopted this approach

### 6.2 SCL-180 Advantages

Compared to SKY130, **SCL-180** offers:

- A more mature process node with >20 years in production
- Long-term field data and reliability statistics
- Well-understood pad behavior and ESD robustness
- Strong foundry support for classical digital flows

Given that **external reset via pad + synchronizer** is already demonstrated on SKY130, adopting the same pattern on a **more mature 180 nm process** is a conservative, low-risk engineering choice.

---

## 7. Design Review and Sign-Off Checklist

### 7.1 Architectural Decision

- [ ] On-chip POR circuitry **removed** from design
- [ ] External reset via SCL-180 Schmitt pad **approved**
- [ ] Risk acceptance and rationale documented
- [ ] Schedule impact positive (analog POR design and validation eliminated)

### 7.2 Pad-Level Specification

- [ ] Reset pad cell selected from SCL library (e.g., Schmitt input type)
- [ ] VTH− and VTH+ extracted and documented
- [ ] Pad propagation delay included in STA constraints
- [ ] ESD rating (≥2 kV HBM) verified from PDK documentation

### 7.3 External Circuit Definition

- [ ] RC debounce network specified (R = 10–100 kΩ, C ≈ 0.1 µF)
- [ ] 10τ ≥ 10 ms confirmed for bounce suppression
- [ ] Component tolerance requirements written into BOM
- [ ] Schematic and PCB annotation clearly describe reset network

### 7.4 Internal Reset Synchronization

- [ ] Reset synchronizers instantiated **per clock domain** (2–3 FFs each)
- [ ] Reset recovery/removal timing validated in STA across PVT corners
- [ ] No illegal reset re-convergence paths between domains
- [ ] Optional: formal checks for synchronizer correctness and CDC safety

### 7.5 Verification Coverage

- [ ] RTL simulations validate correct behavior through multiple reset cycles
- [ ] GLS (post-layout) verifies reset timing and pad delays
- [ ] No reset-related timing violations reported in sign-off STA
- [ ] Documentation updated: reset architecture, timing, and external circuitry

---

## 8. Detailed Justification: Why External Reset Works

### 8.1 The Fundamental Difference

**On-Chip POR (Problematic):**

```
Power Supplied (uncontrolled ramp)
    ↓
POR analog circuit (unpredictable timing)
    ↓
Reset signal to flip-flops (timing varies with voltage, temperature)
    ↓
Metastability risk at clock domain crossings
```

**External Reset (Safe):**

```
User/Firmware triggers external reset source
    ↓
RC network filters transients
    ↓
Schmitt pad cleanly thresholds the signal
    ↓
Synchronizer flops isolate timing
    ↓
Verified digital reset distribution
```

The external approach **decouples** the reset mechanism from analog supply supervision, eliminating unpredictable PVT dependencies.

### 8.2 Why Schmitt Triggers Are Critical

A standard digital input buffer has fixed thresholds that can be affected by supply and temperature:

```
Standard Buffer: Vth ≈ Vdd/2 ± variations → UNSTABLE
Schmitt Trigger: Vth− ≈ 0.7V, Vth+ ≈ 2.4V → STABLE hysteresis
```

The Schmitt trigger:

1. **Rejects noise** below 0.7V or above 2.4V
2. **Provides hysteresis** preventing oscillation near threshold
3. **Is foundry-qualified** with published specifications
4. **Is standard in SCL-180** for all input pads

This is why a simple RC network works: the Schmitt trigger **does the heavy lifting** of converting an analog signal into a clean digital one.

### 8.3 RC Network Design Rules

For a reset button or external source:

| Scenario | R | C | τ | 10τ | Notes |
|----------|---|---|---|----|-------|
| Mechanical button | 10 kΩ | 0.1 µF | 1 ms | 10 ms | Standard choice |
| FPGA-based reset | 10 kΩ | 0.1 µF | 1 ms | 10 ms | FPGA output is stable |
| Wireless trigger | 100 kΩ | 0.1 µF | 10 ms | 100 ms | Longer settling for EM noise |

**Key Constraint:**

10τ must exceed the longest expected noise transient or switch bounce. For typical mechanical buttons, 10 ms is sufficient.

### 8.4 Synchronizer-Based Reset Distribution

Inside the ASIC, the reset signal from the pad must be **synchronized to each clock domain independently**:

```verilog
// Example: Triple-flop synchronizer for one clock domain
module reset_sync (
    input clk,
    input async_reset_n,  // From pad (active-low)
    output reg sync_reset_n
);
    reg sync_ff1, sync_ff2;
    
    always @(posedge clk or negedge async_reset_n) begin
        if (!async_reset_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
            sync_reset_n <= 1'b0;
        end else begin
            sync_ff1 <= 1'b1;
            sync_ff2 <= sync_ff1;
            sync_reset_n <= sync_ff2;
        end
    end
endmodule
```

**Why Three Flops?**

- **FF1**: Captures async input; high metastability probability
- **FF2**: Reduces metastability exponentially
- **FF3**: Output is fully synchronized; safe to use

**Timing Requirements:**

- Reset recovery time (tRecovery) must be met from sync_reset_n to all downstream flip-flops
- This is verified via static timing analysis
- No need to verify metastability probability manually; synchronizer flops are marked in constraints

---

## 9. Common Objections and Responses

### Objection 1: "What if the external reset button fails?"

**Response:**

A **watchdog timer** monitors firmware execution:

```verilog
// Watchdog in firmware
watchdog_timer = 0;
while (1) {
    // ... main loop ...
    if (watchdog_timer >= TIMEOUT)
        trigger_internal_reset();
    watchdog_timer++;
}
```

If the system hangs (firmware stuck or infinite loop), the watchdog asserts an internal reset independent of external button.

**Multiple reset sources** also provide redundancy:

- User button
- JTAG/debug reset (if used)
- Watchdog-triggered reset
- (Optional) pin strapping for special modes

### Objection 2: "Won't external reset add propagation delay?"

**Response:**

Pad delay + synchronizer delay are:

- **Pad Schmitt input**: ~1–3 ns (specified in SDF)
- **Synchronizer settling**: ~2 clock cycles (acceptable for reset)
- **Total**: <20 ns for typical 10 ns clocks

This is **negligible** because:

1. Reset propagation timing is not on any functional critical path
2. Reset release timing is inherently ~milliseconds (RC time constant), not nanoseconds
3. STA will flag any illegal reset recovery violations; design accommodates this

### Objection 3: "Can ESD on the reset pad cause problems?"

**Response:**

- SCL-180 reset pads have **foundry-specified ESD protection** (≥2 kV HBM)
- Standard ASIC handling procedures (wrist straps, grounded workstations) prevent static discharge
- External circuit does not introduce new ESD risk; the pad itself is protected

---

## 10. Verification Plan

### 10.1 RTL-Level Validation

**Test Sequence:**

```tcl
# Test 1: Normal reset
assert_reset_deasserts_cleanly()

# Test 2: Reset held longer than necessary
assert_extra_reset_cycles_harmless()

# Test 3: Reset released during instruction fetch
assert_reset_releases_correctly()

# Test 4: Multiple reset cycles
repeat_reset_deassert_cycles(100)

# Test 5: Watchdog interaction
assert_watchdog_triggers_internal_reset()
```

### 10.2 GLS Validation

**Checks:**

- [ ] Pad propagation delay properly annotated in SDF
- [ ] Synchronizer reset recovery timing verified with STA
- [ ] No reset-related timing violations in sign-off report
- [ ] Reset sequence produces expected waveforms in gate-level simulation

### 10.3 Formal Verification (Optional but Recommended)

- Prove that **reset synchronizer cannot cause observable metastability** using formal tools
- Verify that **reset properly reaches all asynchronous reset inputs** using CDC analysis
- Confirm **no reset fan-out re-convergence** between clock domains

---
---

## 11. Conclusion

### 11.1 Summary of Arguments

1. **On-chip POR is fundamentally an analog supervision block**, sensitive to process, voltage, temperature, ramp characteristics, and noise. Embedding it in a digital-focused SCL-180 ASIC flow imposes analog design and verification burdens that are disproportionate to its value.

2. **RTL-based or purely digital POR is not a safe substitute**. It cannot reliably handle asynchronous power-up conditions without introducing metastability risk that exceeds what can be analyzed by standard digital tools.

3. **SCL-180 reset pads provide a robust, characterized, and production-proven interface**. The combination of Schmitt-trigger inputs, foundry qualification, and external RC filtering produces a clean digital reset signal without any custom analog design.

4. **External reset is widely validated in industry**, including across the open-source SKY130 ecosystem and commercial 130/180 nm designs. The architecture of "external reset → Schmitt pad → synchronizer" is a de-facto standard.

5. **Residual risks are well understood and mitigated** through watchdog timers, multiple reset sources, conservative timing margins, and formal verification of synchronizers and CDCs.

### 11.2 Sign-Off Statement

**Adopting a POR-free, pad-based external reset architecture on SCL-180 is a technically sound, low-risk, and industry-aligned decision.** It simplifies the design, removes analog uncertainties, and enables fully digital, verifiable reset behavior suitable for production ASICs.



.
