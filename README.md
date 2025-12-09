# TinyTinyTPU

A minimal 2×2 systolic-array TPU-style matrix-multiply unit, implemented in Verilog.

The design now models the full post-MAC pipeline: MMU → accumulator (alignment + double buffering) → activation + normalization + loss → quantization → unified buffer.

⸻

## 📦 Project Structure Overview

This repository contains:
	•	Processing Element (PE) building block
	•	2×2 Matrix Multiply Unit (MMU) composed of four PEs
	•	Weight FIFOs (single-column and dual-column) for staggered loading
	•	Double-buffered accumulator with column alignment
	•	Activation/normalization/loss/quantization pipeline feeding the unified buffer
	•	Byte-wide unified buffer with ready/valid backpressure
	•	Comprehensive module and integration testbenches

Together, they form a tiny but faithful model of a systolic TPU pipeline.

⸻

## 🔧 Core RTL Modules

### pe.v — Processing Element
The PE is the fundamental compute block.
	•	Multiply–Accumulate (MAC): psum_out = psum_in + (in_act × weight)  
	•	Data forwarding (activation right, partial sum down)  
	•	Weight loading (weight-stationary column capture)  

Design Notes
	•	Single-cycle, no FSM  
	•	Systolic-friendly timing for TPU-style arrays  

⸻

### mmu.v — 2×2 Systolic Array
<img width="1653" height="1006" alt="image" src="https://github.com/user-attachments/assets/1fd684af-5f78-400a-a9c2-f6056643a7b6" />

Instantiates PEs in a grid:
PE00 → PE01
  ↓      ↓
PE10 → PE11

Responsibilities
	•	Feeds activations into the top row  
	•	Loads weights into each column (from weight FIFOs)  
	•	Emits two partial-sum columns to the accumulator  

⸻

### weight_fifo.v — Single-Column FIFO
Tiny 4-entry circular buffer for a single weight stream.
	•	`push` from the DDR/narrow bus  
	•	`pop` to the MMU column during `en_load_weight`  

### dual_weight_fifo.v — Staggered Load / Parallel Pop
Two independent 4-entry queues share one data bus to fill both MMU columns.
	•	Staggered `push_col0` / `push_col1` loads  
	•	Single `pop` emits both column weights in lockstep  

⸻

### accumulator.v (+ accumulator_align.v, accumulator_mem.v)
Captures MMU outputs, aligns staggered columns, and supports accumulate/overwrite with double buffering.
	•	`accumulator_align` deskews the two column beats (col0 @ T, col1 @ T+1) into a paired write  
	•	`accumulator_mem` stores 2×2 int32 results with buffer select and optional accumulation; bypasses the just-written value when enabled  
	•	Outputs 32-bit columns for downstream activation

⸻

### activation_func.v
Selectable activation (parameter `DEFAULT_ACT`): passthrough, ReLU, or ReLU6.

### normalizer.v
Fixed-point affine transform: `(data * gain) >> shift + bias` with valid pipelining.

### loss_block.v
Computes L1 loss per element: `|data_in - target_in|` with valid passthrough.

### activation_pipeline.v
Top-level post-accumulator stage:
	1) Activation (activation_func)  
	2) Normalization (gain/bias/shift)  
	3) Parallel loss computation  
	4) Affine int8 quantization to UB (`q_inv_scale`, `q_zero_point`, saturating [-128,127])  
Produces ready/valid-aligned outputs for the unified buffer plus optional loss taps.

⸻

### unified_buffer.v — Ready/Valid FIFO
Byte-wide synchronous FIFO with backpressure.
	•	`wr_valid`/`wr_ready` interface from activation_pipeline  
	•	`rd_ready`/`rd_valid` interface to consumers  
	•	Tracks `full`, `empty`, and element `count`  

⸻

## 🧪 Testbenches

pe_tb.v — PE behavior (MAC, forwarding, psum propagation)  
mmu_tb.v — Weight-load then activation-stream phases; checks 2×2 multiply correctness  
weight_fifo_tb.v — Single-column push/pop order and depth behavior  
dual_weight_fifo_tb.v — Interleaved pushes over shared bus + parallel pop  
accumulator_tb.v — Column deskew + accumulate/overwrite paths and double-buffer select  
activation_pipeline_tb.v — Activation/normalization/quantization/loss scoreboard with varying scales and bias  
unified_buffer_tb.v — Ready/valid protocol, fullness, ordering, and backpressure  
accel_integration_tb.v — End-to-end accumulator → activation_pipeline → unified_buffer flow with backpressure

⸻

## 📁 File Layout

tinytinyTPU/
│
├── tinytinyTPU.srcs/
│   ├── sources_1/new/
│   │   ├── pe.v
│   │   ├── mmu.v
│   │   ├── weight_fifo.v
│   │   ├── dual_weight_fifo.v
│   │   ├── accumulator_align.v
│   │   ├── accumulator_mem.v
│   │   ├── accumulator.v
│   │   ├── activation_func.v
│   │   ├── normalizer.v
│   │   ├── loss_block.v
│   │   ├── activation_pipeline.v
│   │   └── unified_buffer.v
│   └── sim_1/new/
│       ├── pe_tb.v
│       ├── mmu_tb.v
│       ├── weight_fifo_tb.v
│       ├── dual_weight_fifo_tb.v
│       ├── accumulator_tb.v
│       ├── activation_pipeline_tb.v
│       ├── accel_integration_tb.v
│       └── unified_buffer_tb.v
│
├── tinytinyTPU.xpr        # Vivado project file
└── README.md              # (you are here)

Note:
All .cache/, .sim/, .wdb, .jou, .log files are Vivado-generated.
