# C906 Processor Synthesis and Power Simulation Methodology

## 1. Overview of the C906 Processor

The XuanTie C906 is a 64-bit RISC-V processor core developed by T-Head. It is
designed as an embedded application processor with support for the RV64GC class
instruction set, T-Head custom extensions, virtual memory, floating-point
execution, and optional vector processing. Public descriptions characterize the
C906 as an in-order processor with a 5-8 stage pipeline, Sv39 virtual memory
support, configurable instruction and data caches, a 128-bit AXI master
interface, standard interrupt infrastructure, and hardware debug support.

The openC906 implementation used in this work provides a complete synthesizable
RTL model of the processor and a system-level simulation environment. At the
microarchitectural level, the core is organized into conventional front-end and
back-end units, including instruction fetch, decode, integer execution,
load-store, retirement, control and status registers, memory management, bus
interface, floating-point/vector execution, and debug/trace logic. The
simulation platform surrounds the core with memory, interconnect, UART, GPIO,
and interrupt components, allowing bare-metal software and neural-network
workloads to execute on the RTL.

The processor is particularly relevant for edge-AI studies because it combines a
general-purpose RISC-V execution environment with floating-point and vector
capabilities. However, practical neural-network deployment on this RTL also
depends on the available compiler and software stack. In this work, ONNX models
are lowered through the TVM/HHB ecosystem into C906-oriented C code and linked
with CSI-NN2 runtime components. Since the C906 vector extension corresponds to
an older RVV generation than that supported by some modern compilers, the
reference C implementation is used when vectorized kernels are not compatible
with the available toolchain.

## 2. Synthesis Methodology

The synthesis flow converts the openC906 RTL into a gate-level representation
that can be used for timing, area, and power analysis. The target technology in
this repository is a TSMC 28HPC+ standard-cell and SRAM macro environment. The
overall synthesis methodology consists of memory macro preparation, RTL
elaboration, technology binding, timing constraint application, logic
optimization, and output generation for downstream power analysis.

### 2.1 Memory Macro Preparation

The C906 RTL contains several SRAM structures associated with the instruction
cache, data cache, memory management unit, branch prediction structures, and
other internal storage. In a realistic ASIC flow, these memories should not be
implemented as synthesized flip-flop arrays because that would produce
unrepresentative area, timing, and power results. Instead, the behavioral
memory descriptions are replaced by foundry SRAM and register-file macros.

The memory preparation stage therefore produces technology-specific memory
views. Functional Verilog models are used where simulation visibility is
required, while Liberty-derived database views are used by synthesis and power
analysis tools for timing, area, and power characterization. These macros are
then exposed to the synthesis tool as hard blocks and linked into the design
through wrapper modules that preserve the logical interface expected by the C906
RTL.

### 2.2 RTL Elaboration and Technology Binding

During synthesis, the complete C906 RTL filelist is read and elaborated with
the processor top module as the design root. FPGA-oriented behavioral SRAM
implementations are excluded from the ASIC synthesis view and replaced by
technology-aware memory wrappers. This substitution preserves the architectural
behavior of the design while producing an implementation that more closely
matches a physical ASIC realization.

The standard-cell libraries and SRAM macro libraries are then provided as the
target and link libraries. This allows the synthesis tool to map combinational
and sequential logic to standard cells while resolving memory instances to
pre-characterized hard macros. Name rules and netlist conventions are also
applied so that the generated gate-level design remains compatible with later
simulation and power-analysis tools.

### 2.3 Constraint Application and Optimization

Timing constraints define the operating clock, design environment, input/output
assumptions, fanout limits, transition constraints, loads, and driving cells.
After elaboration and constraint application, the synthesis tool checks the
design for structural and constraint issues, then performs logic optimization
and technology mapping. The optimization objective is to satisfy timing while
controlling implementation cost, with additional area-oriented optimization
applied after the main compile stage.

The synthesis stage produces a mapped gate-level design, timing constraints
corresponding to the mapped implementation, delay information, and quality
reports. In addition to the conventional mapped netlist and timing artifacts,
the flow generates an RTL-to-gate name mapping file. This mapping is essential
for the subsequent power analysis because the switching activity is obtained
from RTL simulation, whereas power is evaluated on the synthesized gate-level
design.

## 3. Power Simulation Methodology

The power simulation flow estimates workload-dependent power by combining
software workload generation, functional RTL simulation, gate-level power
replay, and waveform post-processing. The procedure is designed to preserve the
connection between high-level neural-network workloads and low-level hardware
activity in the synthesized C906 implementation.

### 3.1 ONNX Model Compilation

The workload begins as an ONNX neural-network model with associated input data.
ONNX provides a portable graph representation, while TVM supplies a compiler
infrastructure for importing ONNX graphs, normalizing tensor shapes and data
types, and lowering the computation toward a target backend. In the C906
deployment flow, HHB is used as the T-Head-oriented frontend built around the
TVM ecosystem. It converts ONNX graphs into C code and binary model artifacts
that call the CSI-NN2 runtime interface.

Model compilation includes graph import, shape resolution, optional graph
partitioning for models that exceed the practical size of the bare-metal test
environment, quantization or data-type selection, code generation, and
cross-compilation for the C906 software environment. The resulting software
payload contains the neural-network graph, model parameters, and input tensors
in a form that can be embedded in or loaded by the bare-metal simulation test.
Representative data types include integer quantized inference as well as
floating-point variants such as float16 and float32.

### 3.2 Functional RTL Simulation

The compiled model is integrated into a bare-metal test program and executed on
the C906 RTL simulation platform. This stage serves two purposes. First, it
verifies that the software workload can complete correctly on the processor
model. Second, it records the cycle-by-cycle switching activity caused by the
workload.

The simulation testbench initializes instruction memory, data memory, and
neural-network input memory, then releases the processor to execute the
bare-metal program. Completion is detected by the testbench through architectural
pass/fail conventions and optional UART output. When waveform dumping is
enabled, the simulator records an FSDB waveform containing the RTL signal
activity of the processor and surrounding system during execution. This FSDB
becomes the activity source for time-based power analysis.

Functional simulation is performed not only for neural-network workloads but
also for architectural and microarchitectural tests, such as integer, load-store,
floating-point, cache, CSR, interrupt, exception, debug, and MMU cases. These
cases provide diverse activity profiles and allow power behavior to be studied
across both AI and non-AI workloads.

### 3.3 Time-Based Power Replay

Power estimation is performed with a time-based replay method. Rather than
using only average toggle rates, the power tool reads the functional simulation
waveform and annotates its switching activity onto the synthesized design. The
mapped gate-level database, mapped timing constraints, standard-cell libraries,
SRAM macro libraries, and RTL-to-gate name map are loaded together to establish
a power-analysis view that is consistent with the synthesis result.

The RTL-to-gate mapping step is a central part of the methodology. The
functional FSDB contains signal names from RTL simulation, while the power
analysis operates on the synthesized design. The mapping file generated during
synthesis allows registers and other mapped objects to be associated with their
gate-level counterparts. The simulation hierarchy is also aligned with the
design hierarchy so that the waveform activity corresponds to the processor core
rather than the surrounding testbench.

After activity annotation, timing is updated and time-based power analysis is
performed. The output includes hierarchical power reports, timing checks,
switching-activity coverage, and a power waveform. The power waveform is
especially useful because it preserves temporal variation, allowing later
analysis to correlate workload phases with instantaneous or windowed power
behavior.

### 3.4 Waveform Sampling and Data Collection

The raw functional and power waveforms are too large and tool-specific for
direct statistical analysis. Therefore, the final stage converts selected
waveform signals into structured tabular data. Functional signal activity and
power waveform quantities are sampled at a defined temporal resolution and
exported to CSV. Signal-selection files constrain the exported set to the
features required for downstream analysis, reducing data volume while preserving
the relevant architectural, microarchitectural, and power observability.

The CSV data is then converted into pandas pickle files. During this conversion,
the time column is normalized into a nanosecond-based index, power values are
converted to a consistent watt unit, digital signal values are normalized into
integer representations, unknown values are handled consistently, and samples
may be downsampled through block averaging. The resulting PKL files form the
compact analysis dataset used for power modeling, workload comparison, feature
extraction, or machine-learning-based power prediction.

## 4. Summary

The methodology links high-level neural-network workloads to low-level hardware
power data through a complete processor implementation and simulation flow. ONNX
models are compiled into C906-executable software, the software is executed on
the RTL model to obtain realistic switching activity, the switching activity is
replayed on the synthesized gate-level design for time-based power estimation,
and the resulting functional and power waveforms are transformed into compact
PKL datasets. This approach allows workload-dependent power behavior to be
studied at the processor level while retaining a clear connection to both the
software workload and the synthesized hardware implementation.

## References

- T-Head openC906 repository: <https://github.com/T-head-Semi/openc906>
- XuanTie C906 public feature summary:
  <https://www.riscvschool.com/2023/03/09/t-head-xuantie-c906-risc-v/>
- Apache TVM ONNX import tutorial:
  <https://daobook.github.io/tvm/docs/how_to/compile_models/from_onnx.html>
- TVM TVMC command-line tutorial source:
  <https://apache.googlesource.com/tvm/+/refs/heads/v0.17.0/gallery/tutorial/tvmc_command_line_driver.py>
- HHB user manual entry point:
  <https://www.xrvm.com/document?temp=hhb-user-manual&slug=hhb-user-manual>

