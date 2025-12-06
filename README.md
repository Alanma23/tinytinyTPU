# TinyTinyTPU

A minimal 2×2 systolic-array TPU-style matrix-multiply unit, implemented in Verilog.

The project showcases the core architectural ideas behind the TPU v1 MMU—Processing Elements, weight-stationary dataflow, systolic wave timing, and post-processing accumulation—shrunk down for clarity and easy simulation.

⸻

## 📦 Project Structure Overview

This repository contains:
	•	A Processing Element (PE) building block
	•	A 2×2 Matrix Multiply Unit (MMU) composed of four PEs
	•	A full Unified Buffer (UB)
	•	A Dual-Weight FIFO for staggered loading
	•	An Accumulator for ReLU + quantization
	•	Complete testbenches for every module

Together, they form a tiny but faithful model of a systolic TPU pipeline.

⸻

## 🔧 Core RTL Modules

### pe.v — Processing Element

The PE is the fundamental compute block.

Each PE performs:
	•	Multiply–Accumulate (MAC)
psum_out = psum_in + (in_act × weight)
	•	Data forwarding
	•	Activation → right
	•	Partial sum → downward
	•	Weight loading (Weight-Stationary mode)

Key Signals

Signal	Description
in_act, out_act	Activation input/output
in_psum, out_psum	Partial sum in/out
load_weight	Captures weight internally

Design Notes
	•	Single-cycle, no FSM
	•	Perfectly suited for systolic + pipelined architectures (e.g., TPU v1)

⸻

### mmu.v — 2×2 Systolic Array

Instantiates PEs in a grid:

PE00 → PE01
  ↓      ↓
PE10 → PE11

Responsibilities
	•	Feeds activations into the top row
	•	Loads weights into the columns (weight-stationary)
	•	Collects final 2×2 matrix output (C matrix)

Dataflow Concept
	•	A activations stream left → right
	•	B weights remain stationary in each PE column
	•	Partial sums accumulate as they move top → bottom

This is a miniature version of the TPU v1 MMU.

⸻

### unified_buffer.v — On-Chip SRAM

The Unified Buffer acts as the system’s central memory.

Responsibilities
	1.	Staggered Feeder
	•	Independent row read-enables
	•	Allows:

Row0 @ T
Row1 @ T+1

enabling the diagonal systolic wave.

	2.	Loopback Storage
	•	Receives accumulator output
	•	Enables multi-layer pipelines

Modeled as a dual-port RAM.

⸻

### dual_weight_fifo.v — Staggered Load / Parallel Pop

Solves the classic bandwidth mismatch between external memory and systolic arrays.

Features
	•	Staggered Push:
Loads weights into two FIFOs via a shared narrow bus.
	•	Parallel Pop:
Outputs both column weights simultaneously during compute.

Internally uses two circular buffers to decouple timing.

⸻

### accumulator.v — Post-Processing

Bridges the gap between 16-bit MAC results and 8-bit storage.

Includes:
	•	ReLU activation (negative clamp)
	•	Quantization / saturation back to 8-bit
(e.g., clamp values >255)

Outputs are written back to the Unified Buffer.

⸻

## 🧪 Testbenches

pe_tb.v — PE Testbench
	•	Verifies standalone PE behavior
	•	Tests MAC correctness, forwarding behavior, and psum propagation

⸻

mmu_tb.v — MMU Testbench

Simulation happens in two phases:
	1.	Weight Load Phase — configure PEs
	2.	Activation Stream Phase — create staggered systolic wave

Checks that output equals A × B for a 2×2 multiply.

⸻

ub_tb.v — Unified Buffer Testbench

Validates:
	•	Correct row-stagger behavior
	•	Correct bubble insertion when rows are disabled

Ensures the systolic wave is preserved.

⸻

dual_weight_fifo_tb.v — FIFO Testbench

Verifies:
	•	Interleaved push sequence (Left, Right, Left, Right)
	•	Simultaneous dual pop outputs

Ensures correct weight availability per column.

⸻

## 📁 File Layout

tinytinyTPU/
│
├── tinytinyTPU.srcs/
│   ├── sources_1/new/
│   │   ├── pe.v
│   │   ├── mmu.v
│   │   ├── unified_buffer.v
│   │   ├── dual_weight_fifo.v
│   │   └── accumulator.v
│   └── sim_1/new/
│       ├── pe_tb.v
│       ├── mmu_tb.v
│       ├── ub_tb.
│       └── dual_weight_fifo_tb.v
│
├── tinytinyTPU.xpr        # Vivado project file
└── README.md              # (you are here)

Note:
All .cache/, .sim/, .wdb, .jou, .log files are Vivado-generated.
