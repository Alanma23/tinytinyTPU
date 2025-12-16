# TinyTinyTPU

A minimal 2×2 systolic-array TPU-style matrix-multiply unit, implemented in Verilog.

The design models the full post-MAC pipeline: **MMU → Accumulator (alignment + double buffering) → Activation + Normalization + Loss → Quantization → Unified Buffer**.

---

## 📦 Project Structure Overview

This repository contains:

- **Processing Element (PE)** building block with separate weight pass/capture controls
- **2×2 Matrix Multiply Unit (MMU)** composed of four PEs with per-column capture enables
- **Weight FIFOs** (single-column and dual-column) with column skew for diagonal wavefront
- **Double-buffered accumulator** with column alignment for skewed MMU outputs
- **Activation/normalization/loss/quantization pipeline** feeding the unified buffer
- **Byte-wide unified buffer** with ready/valid backpressure
- **Comprehensive module and integration testbenches**

Together, they form a tiny but faithful model of a systolic TPU pipeline.

---

## 🔧 Core RTL Modules

### pe.v — Processing Element

The PE is the fundamental compute block.

- **Multiply–Accumulate (MAC):** `psum_out = psum_in + (in_act × weight)`
- **Data forwarding:** activation flows right, partial sum flows down
- **Weight loading:** separate `en_weight_pass` and `en_weight_capture` signals

**Design Notes:**
- Single-cycle registered outputs, no FSM
- `en_weight_pass` controls psum passthrough during entire load phase
- `en_weight_capture` triggers weight register latch on specific cycle
- Systolic-friendly timing for TPU-style arrays

---

### mmu.v — 2×2 Systolic Array

```
PE00 → PE01    Activations flow horizontally (right)
  ↓      ↓     
PE10 → PE11    Partial sums flow vertically (down)
  ↓      ↓
acc0   acc1    Outputs to accumulator
```

**Responsibilities:**
- Feeds activations into rows (row0 direct, row1 with skew register)
- Loads weights via vertical psum path with per-column capture timing
- Emits two partial-sum columns to the accumulator

**Control Signals:**
- `en_weight_pass` — broadcast to all PEs during weight load phase
- `en_capture_col0` — capture enable for PE00, PE10 (column 0)
- `en_capture_col1` — capture enable for PE01, PE11 (column 1, staggered)

---

### dual_weight_fifo.v — Staggered Column Weight FIFO

Two independent 4-entry queues share one data bus to fill both MMU columns.

- **Column 0:** Combinational read output (no latency)
- **Column 1:** Registered output with 1-cycle skew for diagonal wavefront
- Staggered `push_col0` / `push_col1` loads via shared data bus
- Single `pop` signal advances both read pointers

**Column Skew Timing:**
| Cycle | col0_out | col1_out (skewed) |
|-------|----------|-------------------|
| 0 | W[1,0] | 0 (initial) |
| 1 | W[0,0] | W[1,1] |
| 2 | (hold) | W[0,1] |

---

### weight_fifo.v — Single-Column FIFO

Tiny 4-entry circular buffer for a single weight stream.

- `push` from the DDR/narrow bus
- `pop` to the MMU column during weight loading

---

### accumulator.v (+ accumulator_align.v, accumulator_mem.v)

Captures MMU outputs, aligns staggered columns, and supports accumulate/overwrite with double buffering.

**accumulator_align.v:**
- Deskews two column beats (col0 @ T, col1 @ T+1) into paired writes
- Delay register holds col0 until col1 arrives
- Continuous streaming with `pending` flag management

**accumulator_mem.v:**
- Stores 2×2 int32 results with buffer select
- Supports accumulate mode (add to existing) or overwrite mode
- `BYPASS_READ_NEW` parameter outputs newly written value same cycle
- Outputs 32-bit columns for downstream activation

---

### activation_func.v

Selectable activation (parameter `DEFAULT_ACT`): passthrough, ReLU, or ReLU6.

### normalizer.v

Fixed-point affine transform: `(data * gain) >> shift + bias` with valid pipelining.

### loss_block.v

Computes L1 loss per element: `|data_in - target_in|` with valid passthrough.

### activation_pipeline.v

Top-level post-accumulator stage:

1. Activation (activation_func)
2. Normalization (gain/bias/shift)
3. Parallel loss computation
4. Affine int8 quantization to UB (`q_inv_scale`, `q_zero_point`, saturating [-128,127])

Produces ready/valid-aligned outputs for the unified buffer plus optional loss taps.

---

### unified_buffer.v — Ready/Valid FIFO

Byte-wide synchronous FIFO with backpressure.

- `wr_valid`/`wr_ready` interface from activation_pipeline
- `rd_ready`/`rd_valid` interface to consumers
- Tracks `full`, `empty`, and element `count`
- Combinational read output for zero-latency data availability

---

## 🔄 Diagonal Wavefront Weight Loading

The 3-cycle staggered weight loading scheme ensures weights propagate through the systolic array in a proper diagonal wavefront pattern.

### Weight Loading Sequence (3 cycles)

For weight matrix W = [[1, 2], [3, 4]]:

| Cycle | col0_out | col1_out | Column 0 Captures | Column 1 Captures |
|-------|----------|----------|-------------------|-------------------|
| 0 | 3 | 0 (skew) | ✗ | ✗ |
| 1 | 1 | 4 | ✓ PE00→1, PE10→3 | ✗ |
| 2 | (hold) | 2 | ✗ | ✓ PE01→2, PE11→4 |

### Final Weight Distribution

```
PE00: W[0,0]=1    PE01: W[0,1]=2
PE10: W[1,0]=3    PE11: W[1,1]=4
```

**Key Design Points:**
- `en_weight_pass` active for all 3 cycles (psum passthrough)
- `en_capture_col0` asserts on cycle 1 only
- `en_capture_col1` asserts on cycle 2 only
- FIFO column skew creates 1-cycle offset between columns

---

## 🚀 End-to-End Forward Pass

The forward pass executes C = A × W through five FSM phases:

### Phase 0: Weight Loading (3 cycles)

The dual weight FIFO feeds weights into the MMU's vertical psum paths with staggered column timing. Each PE captures its weight on the designated cycle based on its column position.

### Phase 1: Activation Loading

The activation matrix A = [[5, 6], [7, 8]] is loaded into the unified buffer as 16-bit packed words. Each entry contains both row values: `{row1_data, row0_data}`.

### Phase 2: Compute (3 cycles)

The systolic array performs matrix multiplication with diagonal wavefront:

- Row 0 receives data directly when buffer is valid
- Row 1 passes through a skew register (1-cycle delay)
- Each PE computes: `out_psum = (in_act × weight) + in_psum`

**Expected Results:**
```
C[0,0] = 5×1 + 6×3 = 23    C[0,1] = 5×2 + 6×4 = 34
C[1,0] = 7×1 + 8×3 = 31    C[1,1] = 7×2 + 8×4 = 46
```

### Phase 3: Drain

The FSM flushes remaining partial sums through the pipeline. The accumulator alignment stage pairs skewed column outputs before writing to memory.

### Phase 4: Timing Verification

The testbench validates:
- Weight load duration: 3 cycles
- Compute duration: 3 cycles
- First accumulator output delay: 5 cycles from compute start
- Accumulator output spacing: 1 cycle between valid pairs

---

## 🔁 Multi-Layer MLP Inference

The `mlp_integration_tb.v` demonstrates multi-layer neural network inference following TPU v1 architecture:

### Architecture (per Jouppi et al., 2017)

```
Weight FIFO → MMU (systolic) → Accumulator → Activation Pipeline → UB
                ↑                                                    │
                └──────────── feedback (next layer input) ──────────┘
```

### Ping-Pong Unified Buffers

For layer-to-layer data flow, two unified buffers alternate roles:
- **Layer N:** UB_A is input, UB_B receives quantized output
- **Layer N+1:** UB_B is input, UB_A receives quantized output

### 2-Layer MLP Demo

```
Input:  A  = [[5, 6], [7, 8]]

Layer 1: H = ReLU(A × W1)    where W1 = [[1, 2], [3, 4]]
         H = [[23, 34], [31, 46]]

Layer 2: Y = ReLU(H × W2)    where W2 = [[1, 1], [1, 1]]
         Y = [[57, 57], [77, 77]]
```

### FSM States for Multi-Layer

| State | Description |
|-------|-------------|
| `LOAD_WEIGHT` | Load weights for current layer (3 cycles) |
| `LOAD_ACT` | Load initial activations (layer 0 only) |
| `COMPUTE` | Systolic array matrix multiply (3 cycles) |
| `DRAIN` | Flush pipeline, write to output buffer |
| `TRANSFER` | Repack 8-bit outputs to 16-bit packed format |
| `NEXT_LAYER` | Swap buffers, reset FIFO, advance layer counter |

---

## 🧪 Testbenches

| Testbench | Description |
|-----------|-------------|
| `pe_tb.v` | PE behavior (MAC, forwarding, psum propagation) |
| `mmu_tb.v` | Weight-load then activation-stream phases; checks 2×2 multiply |
| `weight_fifo_tb.v` | Single-column push/pop order and depth behavior |
| `dual_weight_fifo_tb.v` | Interleaved pushes over shared bus + parallel pop with skew |
| `accumulator_tb.v` | Column deskew + accumulate/overwrite paths and double-buffer |
| `activation_pipeline_tb.v` | Activation/normalization/quantization/loss with varying scales |
| `unified_buffer_tb.v` | Ready/valid protocol, fullness, ordering, and backpressure |
| `accel_integration_tb.v` | End-to-end forward pass with timing verification |
| `mlp_integration_tb.v` | Multi-layer MLP inference with ping-pong buffers |

---

## 📁 File Layout

```
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
│       ├── mlp_integration_tb.v
│       └── unified_buffer_tb.v
│
├── tinytinyTPU.xpr        # Vivado project file
└── README.md              # (you are here)
```

**Note:** All `.cache/`, `.sim/`, `.wdb`, `.jou`, `.log` files are Vivado-generated.

---

## 📊 Pipeline Timing Summary

| Phase | Duration | Description |
|-------|----------|-------------|
| Weight Load | 3 cycles | Staggered column capture with diagonal wavefront |
| Compute | 3 cycles | Activation streaming with row skew |
| First Result | 5 cycles | From compute start to first accumulator output |
| Result Spacing | 1 cycle | Between consecutive valid accumulator outputs |
