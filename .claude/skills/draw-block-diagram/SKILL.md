---
name: draw-block-diagram
description: Draw an ASCII block diagram from a given Verilog/SystemVerilog module. This Skill must be explicitly invoked by the user; the agent must not call it automatically.
---

Draw a block diagram of the Verilog/SystemVerilog module the user provides
(as a pasted snippet or a file path). The diagram must show all of the top
module's inputs and outputs and the main dataflow between the submodules
inside it.

## Output format
- Render the diagram as **ASCII art in a monospace code block** (not Mermaid,
  Graphviz, or an image). All the box/wire/joint rules below assume monospace
  text.
- Place the diagram first, then a short **Summary** section below it for any
  bus explanations (see rule 4).

## Drawing rules
1. Draw each submodule as a box, marking only the module name on it. If a block
   is glue logic, work out what it does, wrap it into a virtual box, and give
   that box a short descriptive name.
2. For each box, explicitly show the input and output data width.
3. Do not draw a bounding box around the top module.
4. Do not explain the data buses on the graph. If explanation is needed, put it
   in the Summary section below the graph.
5. Every wire must end in an arrow, and every wire must be named.
6. Except for the top module's inputs and outputs, every intermediate wire's
   start and end point must be a submodule.
7. Mark each wire's width using `(xxb)`, where `xx` is the bit width — e.g.
   `sig_a(8192b)`.
8. Leave ample space between submodules so the wires are not crowded together.
9. Draw each submodule large enough that its input and output wires are not
   crowded together.
10. If two lines connect, use `+` to show the joint.
11. For multiple instances of a block, mark it with `(*xx)`, where `xx` is the
    instance count — e.g. N multipliers is `mult(*N)`.
12. When drawing a straight line, keep it continuous — do not break it in the
    middle.
13. Show only the module name (e.g. `U_FP32_NORM`), not the file name (e.g.
    `fp32_norm_bf16`).
