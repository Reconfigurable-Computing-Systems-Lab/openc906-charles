#!/usr/bin/env python3
"""ONNX -> CSI-NN2 bare-metal case generator (fp32, CSINN_REF backend).

Replaces HHB for the OpenC906 RTL-sim flow. Given an ONNX model and a sample
input, emits a case directory that `make runcase` can build:

    <out>/model.c           graph builder  void *csinn_(char *params_base)
    <out>/blob.bin          [ PARAMS(qinfo+weights) | INPUT | GOLDEN ]  little-endian image
    <out>/model_config.h    base addr + per-input/output offsets, sizes, tolerances
    <out>/meta.json         provenance / shapes / node range
    <out>/GENERATED         marker => prepare_model.py uses passthrough mode

Weights never enter the ELF: the whole blob is loaded by the testbench into SRAM
at PARAMS_BASE_ADDR (0x01000000, the 32 MB NN-input window) and csinn_() reads
qinfo/const-data through params_base pointers. Goldens are computed with
onnxruntime (fallback: onnx.reference) on the CPU.

The generator works on a contiguous node range [start,end] of the model, so the
SAME code emits either the whole model (capstone) or an independently-verifiable
segment (cut at an articulation point where exactly one activation crosses the
boundary). Segment input values / goldens are read from the full-model reference
run, so segments are independent and run in parallel.

Usage:
  onnx2csinn.py --onnx M.onnx --input-npz in.npz --out DIR [--start A --end B]
                [--name NAME] [--rtol R] [--atol A]
"""
import argparse
import json
import os
import struct
import sys

import numpy as np
import onnx
from onnx import numpy_helper, shape_inference

PARAMS_BASE_ADDR = 0x01000000
ALIGN = 16


def _align(x, a=ALIGN):
    return (x + a - 1) & ~(a - 1)


class Blob:
    """Byte buffer with aligned allocation; records region boundaries."""

    def __init__(self):
        self.buf = bytearray()

    def alloc(self, data: bytes, align=ALIGN):
        off = _align(len(self.buf), align)
        self.buf.extend(b"\x00" * (off - len(self.buf)))
        self.buf.extend(data)
        return off

    def reserve_qinfo(self, n=1):
        # csinn_quant_info = {i32 zero_point, f32 scale, i32 mult, i32 shift, f32 min, f32 max} = 24 B
        qi = struct.pack("<ifiiff", 0, 1.0, 1, 0, 0.0, 0.0) * n
        return self.alloc(qi, align=8)

    def __len__(self):
        return len(self.buf)


def eval_constants(graph):
    """Return {output_name: np.ndarray} for every Constant node (value attr)."""
    consts = {}
    for n in graph.node:
        if n.op_type != "Constant":
            continue
        for a in n.attribute:
            if a.name == "value":
                consts[n.output[0]] = numpy_helper.to_array(a.t)
    return consts


def infer_shape_map(model):
    m = shape_inference.infer_shapes(model)
    g = m.graph
    vi = {}
    for v in list(g.value_info) + list(g.input) + list(g.output):
        dims = [d.dim_value for d in v.type.tensor_type.shape.dim]
        vi[v.name] = dims
    return m, vi


def reference_run(model, feeds, want_names):
    """Run the model, return {name: np.ndarray(float32)} for want_names.

    Adds want_names as graph outputs so intermediate tensors are retrievable.
    Prefers onnxruntime; falls back to onnx.reference.ReferenceEvaluator.
    """
    m = onnx.ModelProto()
    m.CopyFrom(model)
    existing = {o.name for o in m.graph.output}
    for name in want_names:
        if name not in existing:
            m.graph.output.append(onnx.helper.make_empty_tensor_value_info(name))
    try:
        import onnxruntime as ort

        so = ort.SessionOptions()
        so.graph_optimization_level = ort.GraphOptimizationLevel.ORT_DISABLE_ALL
        sess = ort.InferenceSession(m.SerializeToString(), so,
                                    providers=["CPUExecutionProvider"])
        outs = sess.run(list(want_names), {k: v for k, v in feeds.items()})
        return {n: np.asarray(o, dtype=np.float32) for n, o in zip(want_names, outs)}
    except Exception as e:  # pragma: no cover
        sys.stderr.write(f"onnxruntime unavailable/failed ({e}); using onnx.reference\n")
        from onnx.reference import ReferenceEvaluator

        ev = ReferenceEvaluator(m)
        res = ev.run(list(want_names), {k: v for k, v in feeds.items()})
        return {n: np.asarray(o, dtype=np.float32) for n, o in zip(want_names, res)}


class Emitter:
    def __init__(self):
        self.lines = []
        self.var_of = {}      # tensor name -> C var
        self.n = 0

    def newvar(self, name, prefix="t"):
        v = f"{prefix}{self.n}"
        self.n += 1
        self.var_of[name] = v
        return v

    def w(self, s):
        self.lines.append(s)


def emit_tensor(em, blob, name, dims, *, is_const=False, const_bytes=None,
                layout="CSINN_LAYOUT_NCHW", var_prefix="t"):
    """Emit a csinn_tensor declaration; return its C var name."""
    var = em.newvar(name, var_prefix)
    qoff = blob.reserve_qinfo(1)
    em.w(f"  struct csinn_tensor *{var} = csinn_alloc_tensor(sess);")
    if is_const:
        doff = blob.alloc(const_bytes)
        em.w(f"  {var}->data = params_base + {doff};")
        em.w(f"  {var}->is_const = 1;")
        em.w(f"  {var}->mtype = CSINN_MEM_TYPE_CPU_ALIGNED;")
    em.w(f"  {var}->dtype = CSINN_DTYPE_FLOAT32;")
    em.w(f"  {var}->layout = {layout};")
    for i, d in enumerate(dims):
        em.w(f"  {var}->dim[{i}] = {d};")
    em.w(f"  {var}->dim_count = {len(dims)};")
    em.w(f"  {var}->qinfo = (struct csinn_quant_info *)(params_base + {qoff});")
    em.w(f"  {var}->quant_channel = 1;")
    return var


def f32_bytes(arr):
    return np.ascontiguousarray(arr, dtype="<f4").tobytes()


def generate(onnx_path, input_npz, out_dir, start, end, name, rtol, atol):
    model = onnx.load(onnx_path)
    model, vi = infer_shape_map(model)
    g = model.graph
    init = {t.name: numpy_helper.to_array(t) for t in g.initializer}
    consts = eval_constants(g)
    nodes = list(g.node)
    N = len(nodes)
    if end < 0:
        end = N - 1
    graph_out = {o.name for o in g.output}

    producer = {}
    for i, nd in enumerate(nodes):
        for o in nd.output:
            if o:
                producer[o] = i
    consumers = {}
    for i, nd in enumerate(nodes):
        for x in nd.input:
            if x and x not in init and x not in consts:
                consumers.setdefault(x, []).append(i)

    rng = range(start, end + 1)
    produced_in_range = set()
    for i in rng:
        for o in nodes[i].output:
            if o:
                produced_in_range.add(o)

    # External inputs: consumed in range, not produced in range, not const/init.
    ext_inputs = []
    seen = set()
    for i in rng:
        nd = nodes[i]
        if nd.op_type == "Constant":
            continue
        for x in nd.input:
            if not x or x in init or x in consts or x in produced_in_range:
                continue
            if x not in seen:
                seen.add(x)
                ext_inputs.append(x)

    # Outputs: produced in range, consumed outside range OR graph output.
    seg_outputs = []
    for i in rng:
        for o in nodes[i].output:
            if not o:
                continue
            cs = consumers.get(o, [])
            if o in graph_out or any((c < start or c > end) for c in cs):
                seg_outputs.append(o)
    if not seg_outputs:  # last node's output is the segment output
        seg_outputs = [o for o in nodes[end].output if o]

    # Reference run for input activations + goldens.
    npz = np.load(input_npz)
    feeds = {k: np.asarray(npz[k], dtype=np.float32) for k in npz.files}
    want = list(dict.fromkeys(ext_inputs + seg_outputs))
    # Graph inputs among ext_inputs are already in feeds; only fetch the rest.
    fetch = [w for w in want if w not in feeds]
    refvals = reference_run(model, feeds, fetch) if fetch else {}
    values = dict(feeds)
    values.update(refvals)

    blob = Blob()
    em = Emitter()
    em.w("/* auto-generated by onnx2csinn.py -- fp32 CSINN_REF */")
    em.w("#include <csi_nn.h>")
    em.w("#include <shl_utils.h>")
    em.w("")
    em.w("void *csinn_(char *params_base) {")
    em.w("  struct csinn_session *sess = csinn_alloc_session();")
    em.w("  sess->base_run_mode = CSINN_RM_CPU_GRAPH;")
    em.w("  sess->base_quant_type = CSINN_QUANT_FLOAT32;")
    em.w("  sess->model.save_mode = CSINN_RUN_ONLY;")
    em.w("  sess->base_api = CSINN_REF;")
    em.w("  sess->base_dtype = CSINN_DTYPE_FLOAT32;")
    em.w("  sess->dynamic_shape = CSINN_FALSE;")
    em.w("  csinn_session_init(sess);")
    em.w(f"  csinn_set_input_number({len(ext_inputs)}, sess);")
    em.w(f"  csinn_set_output_number({len(seg_outputs)}, sess);")
    em.w("")

    def dims_of(nm):
        d = vi.get(nm)
        if d:
            return d
        if nm in values:
            return list(values[nm].shape)
        raise KeyError(f"no shape for {nm}")

    # Emit external input tensors.
    for nm in ext_inputs:
        emit_tensor(em, blob, nm, dims_of(nm), var_prefix="in")

    exec_calls = []
    # Emit ops in topological (node) order.
    for i in rng:
        nd = nodes[i]
        op = nd.op_type
        if op == "Constant":
            continue
        if op == "Conv":
            _emit_conv(em, blob, nd, vi, init, dims_of, exec_calls)
        elif op == "Clip":
            _emit_clip(em, blob, nd, consts, dims_of, exec_calls)
        elif op == "Relu":
            _emit_relu(em, blob, nd, dims_of, exec_calls)
        elif op == "Add":
            _emit_add(em, blob, nd, dims_of, exec_calls)
        elif op == "GlobalAveragePool":
            _emit_gap(em, blob, nd, dims_of, exec_calls)
        elif op == "Flatten":
            _emit_flatten(em, blob, nd, dims_of, exec_calls)
        elif op == "Reshape":
            _emit_reshape(em, blob, nd, dims_of, exec_calls)
        elif op == "Gemm":
            _emit_gemm(em, blob, nd, init, dims_of, exec_calls)
        else:
            raise NotImplementedError(f"op {op} (node {i})")

    em.w("")
    for nm in ext_inputs:
        em.w(f"  csinn_set_tensor_entry({em.var_of[nm]}, sess);")
    for k, nm in enumerate(ext_inputs):
        em.w(f"  csinn_set_input({k}, {em.var_of[nm]}, sess);")
    em.w("")
    for call in exec_calls:
        em.w("  " + call)
    for k, nm in enumerate(seg_outputs):
        em.w(f"  csinn_set_output({k}, {em.var_of[nm]}, sess);")
    em.w("")
    em.w("  csinn_session_setup(sess);")
    em.w("  return sess;")
    em.w("}")

    params_size = len(blob)

    # INPUT region.
    input_meta = []
    for nm in ext_inputs:
        arr = np.asarray(values[nm], dtype=np.float32)
        off = blob.alloc(f32_bytes(arr))
        input_meta.append((nm, off, arr.size, list(arr.shape)))

    # GOLDEN region.
    golden_meta = []
    for nm in seg_outputs:
        arr = np.asarray(values[nm], dtype=np.float32)
        off = blob.alloc(f32_bytes(arr))
        golden_meta.append((nm, off, arr.size, list(arr.shape)))

    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "model.c"), "w") as f:
        f.write("\n".join(em.lines) + "\n")
    with open(os.path.join(out_dir, "blob.bin"), "wb") as f:
        f.write(bytes(blob.buf))

    cfg = []
    cfg.append("#ifndef MODEL_CONFIG_H")
    cfg.append("#define MODEL_CONFIG_H")
    cfg.append(f"#define PARAMS_IN_SRAM 1")
    cfg.append(f"#define MODEL_VERIFY 1")
    cfg.append(f"#define PARAMS_BASE_ADDR 0x{PARAMS_BASE_ADDR:08x}UL")
    cfg.append(f"#define PARAMS_BYTES {params_size}")
    cfg.append(f"#define NUM_BIN_INPUTS {len(input_meta)}")
    for k, (nm, off, sz, shp) in enumerate(input_meta):
        cfg.append(f"#define INPUT{k}_ADDR (PARAMS_BASE_ADDR + {off}UL)")
        cfg.append(f"#define INPUT{k}_ELEMS {sz}")
    cfg.append(f"#define NUM_OUTPUTS {len(golden_meta)}")
    for k, (nm, off, sz, shp) in enumerate(golden_meta):
        cfg.append(f"#define OUTPUT{k}_ADDR (PARAMS_BASE_ADDR + {off}UL)")
        cfg.append(f"#define OUTPUT{k}_ELEMS {sz}")
    in_addrs = ", ".join(f"INPUT{k}_ADDR" for k in range(len(input_meta)))
    in_elems = ", ".join(f"INPUT{k}_ELEMS" for k in range(len(input_meta)))
    out_addrs = ", ".join(f"OUTPUT{k}_ADDR" for k in range(len(golden_meta)))
    out_elems = ", ".join(f"OUTPUT{k}_ELEMS" for k in range(len(golden_meta)))
    cfg.append(f"#define MODEL_INPUT_ADDRS {{ {in_addrs} }}")
    cfg.append(f"#define MODEL_INPUT_ELEMS {{ {in_elems} }}")
    cfg.append(f"#define MODEL_OUTPUT_ADDRS {{ {out_addrs} }}")
    cfg.append(f"#define MODEL_OUTPUT_ELEMS {{ {out_elems} }}")
    cfg.append(f"#define VERIFY_RTOL {rtol}f")
    cfg.append(f"#define VERIFY_ATOL {atol}f")
    # argmax check when a single 2-D classifier output
    if len(golden_meta) == 1 and len(golden_meta[0][3]) == 2:
        cfg.append("#define VERIFY_ARGMAX 1")
    cfg.append("#endif")
    with open(os.path.join(out_dir, "model_config.h"), "w") as f:
        f.write("\n".join(cfg) + "\n")

    meta = {
        "name": name, "onnx": os.path.abspath(onnx_path),
        "node_range": [start, end], "params_bytes": params_size,
        "blob_bytes": len(blob),
        "inputs": [{"name": n, "off": o, "elems": s, "shape": sh} for n, o, s, sh in input_meta],
        "outputs": [{"name": n, "off": o, "elems": s, "shape": sh} for n, o, s, sh in golden_meta],
        "rtol": rtol, "atol": atol,
    }
    with open(os.path.join(out_dir, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    open(os.path.join(out_dir, "GENERATED"), "w").close()

    print(f"[{name}] nodes {start}..{end}  params={params_size}B  blob={len(blob)}B  "
          f"in={[m[0] for m in input_meta]} out={[m[0] for m in golden_meta]}")
    return meta


# ---- per-op emitters -------------------------------------------------------

def _attr(nd):
    d = {}
    for a in nd.attribute:
        if a.type == a.INT:
            d[a.name] = a.i
        elif a.type == a.INTS:
            d[a.name] = list(a.ints)
        elif a.type == a.FLOAT:
            d[a.name] = a.f
    return d


def _emit_conv(em, blob, nd, vi, init, dims_of, calls):
    a = _attr(nd)
    xin = nd.input[0]
    w = init[nd.input[1]]
    oc = w.shape[0]
    kdims = list(w.shape)  # OIHW
    group = a.get("group", 1)
    pads = a.get("pads", [0, 0, 0, 0])
    strides = a.get("strides", [1, 1])
    dil = a.get("dilations", [1, 1])
    out = nd.output[0]
    kv = emit_tensor(em, blob, nd.input[1] + f"@k{em.n}", kdims,
                     is_const=True, const_bytes=f32_bytes(w),
                     layout="CSINN_LAYOUT_OIHW", var_prefix="k")
    if len(nd.input) > 2 and nd.input[2] in init:
        b = init[nd.input[2]]
    else:
        b = np.zeros((oc,), dtype=np.float32)
    bv = emit_tensor(em, blob, out + "@bias", [oc],
                     is_const=True, const_bytes=f32_bytes(b),
                     layout="CSINN_LAYOUT_O", var_prefix="b")
    ov = emit_tensor(em, blob, out, dims_of(out), var_prefix="t")
    p = f"pc{em.n}"
    em.n += 1
    em.w(f"  struct csinn_conv2d_params *{p} = csinn_alloc_params(sizeof(struct csinn_conv2d_params), sess);")
    em.w(f"  {p}->group = {group};")
    em.w(f"  {p}->stride_height = {strides[0]};")
    em.w(f"  {p}->stride_width = {strides[1]};")
    em.w(f"  {p}->dilation_height = {dil[0]};")
    em.w(f"  {p}->dilation_width = {dil[1]};")
    em.w(f"  {p}->conv_extra.kernel_tm = NULL;")
    em.w(f"  {p}->conv_extra.conv_mode = CSINN_DIRECT;")
    em.w(f"  {p}->pad_top = {pads[0]};")
    em.w(f"  {p}->pad_left = {pads[1]};")
    em.w(f"  {p}->pad_down = {pads[2]};")
    em.w(f"  {p}->pad_right = {pads[3]};")
    em.w(f'  {p}->base.name = "conv_{em.n}";')
    em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
    em.w(f"  csinn_conv2d_init({em.var_of[xin]}, {ov}, {kv}, {bv}, {p});")
    calls.append(f"csinn_conv2d({em.var_of[xin]}, {ov}, {kv}, {bv}, {p});")


def _emit_clip(em, blob, nd, consts, dims_of, calls):
    xin = nd.input[0]
    out = nd.output[0]
    lo = float(consts[nd.input[1]]) if len(nd.input) > 1 and nd.input[1] in consts else 0.0
    hi = float(consts[nd.input[2]]) if len(nd.input) > 2 and nd.input[2] in consts else 6.0
    ov = emit_tensor(em, blob, out, dims_of(out), var_prefix="t")
    p = f"pr{em.n}"
    em.n += 1
    if abs(lo) < 1e-6 and abs(hi - 6.0) < 1e-6:
        em.w(f"  struct csinn_relu_params *{p} = csinn_alloc_params(sizeof(struct csinn_relu_params), sess);")
        em.w(f'  {p}->base.name = "relu6_{em.n}";')
        em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
        em.w(f"  csinn_relu6_init({em.var_of[xin]}, {ov}, {p});")
        calls.append(f"csinn_relu6({em.var_of[xin]}, {ov}, {p});")
    else:
        em.w(f"  struct csinn_clip_params *{p} = csinn_alloc_params(sizeof(struct csinn_clip_params), sess);")
        em.w(f"  {p}->min_value = {lo};")
        em.w(f"  {p}->max_value = {hi};")
        em.w(f'  {p}->base.name = "clip_{em.n}";')
        em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
        em.w(f"  csinn_clip_init({em.var_of[xin]}, {ov}, {p});")
        calls.append(f"csinn_clip({em.var_of[xin]}, {ov}, {p});")


def _emit_relu(em, blob, nd, dims_of, calls):
    xin = nd.input[0]
    out = nd.output[0]
    ov = emit_tensor(em, blob, out, dims_of(out), var_prefix="t")
    p = f"pr{em.n}"
    em.n += 1
    em.w(f"  struct csinn_relu_params *{p} = csinn_alloc_params(sizeof(struct csinn_relu_params), sess);")
    em.w(f'  {p}->base.name = "relu_{em.n}";')
    em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
    em.w(f"  csinn_relu_init({em.var_of[xin]}, {ov}, {p});")
    calls.append(f"csinn_relu({em.var_of[xin]}, {ov}, {p});")


def _emit_add(em, blob, nd, dims_of, calls):
    x0, x1 = nd.input[0], nd.input[1]
    out = nd.output[0]
    ov = emit_tensor(em, blob, out, dims_of(out), var_prefix="t")
    p = f"pd{em.n}"
    em.n += 1
    em.w(f"  struct csinn_diso_params *{p} = csinn_alloc_params(sizeof(struct csinn_diso_params), sess);")
    em.w(f'  {p}->base.name = "add_{em.n}";')
    em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
    em.w(f"  csinn_add_init({em.var_of[x0]}, {em.var_of[x1]}, {ov}, {p});")
    calls.append(f"csinn_add({em.var_of[x0]}, {em.var_of[x1]}, {ov}, {p});")


def _emit_gap(em, blob, nd, dims_of, calls):
    xin = nd.input[0]
    out = nd.output[0]
    ov = emit_tensor(em, blob, out, dims_of(out), var_prefix="t")
    p = f"pp{em.n}"
    em.n += 1
    em.w(f"  struct csinn_pool_params *{p} = csinn_alloc_params(sizeof(struct csinn_pool_params), sess);")
    em.w(f'  {p}->base.name = "gap_{em.n}";')
    em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
    em.w(f"  csinn_global_avgpool2d_init({em.var_of[xin]}, {ov}, {p});")
    calls.append(f"csinn_global_avgpool2d({em.var_of[xin]}, {ov}, {p});")


def _emit_flatten(em, blob, nd, dims_of, calls):
    xin = nd.input[0]
    out = nd.output[0]
    ov = emit_tensor(em, blob, out, dims_of(out), var_prefix="t")
    p = f"pf{em.n}"
    em.n += 1
    em.w(f"  struct csinn_flatten_params *{p} = csinn_alloc_params(sizeof(struct csinn_flatten_params), sess);")
    em.w(f'  {p}->base.name = "flatten_{em.n}";')
    em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
    em.w(f"  csinn_flatten_init({em.var_of[xin]}, {ov}, {p});")
    calls.append(f"csinn_flatten({em.var_of[xin]}, {ov}, {p});")


def _emit_reshape(em, blob, nd, dims_of, calls):
    xin = nd.input[0]
    out = nd.output[0]
    ov = emit_tensor(em, blob, out, dims_of(out), var_prefix="t")
    p = f"ps{em.n}"
    em.n += 1
    em.w(f"  struct csinn_reshape_params *{p} = csinn_alloc_params(sizeof(struct csinn_reshape_params), sess);")
    em.w(f'  {p}->base.name = "reshape_{em.n}";')
    em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
    em.w(f"  csinn_reshape_init({em.var_of[xin]}, {ov}, {p});")
    calls.append(f"csinn_reshape({em.var_of[xin]}, {ov}, {p});")


def _emit_gemm(em, blob, nd, init, dims_of, calls):
    a = _attr(nd)
    xin = nd.input[0]
    out = nd.output[0]
    W = init[nd.input[1]]
    if not a.get("transB", 0):
        W = W.T  # csinn fc expects [out, in]
    W = np.ascontiguousarray(W)
    units = W.shape[0]
    accum = W.shape[1]
    wv = emit_tensor(em, blob, nd.input[1] + f"@w{em.n}", [units, accum],
                     is_const=True, const_bytes=f32_bytes(W),
                     layout="CSINN_LAYOUT_OI", var_prefix="w")
    if len(nd.input) > 2 and nd.input[2] in init:
        b = init[nd.input[2]]
    else:
        b = np.zeros((units,), dtype=np.float32)
    bv = emit_tensor(em, blob, out + "@bias", [units],
                     is_const=True, const_bytes=f32_bytes(b),
                     layout="CSINN_LAYOUT_O", var_prefix="b")
    ov = emit_tensor(em, blob, out, dims_of(out), var_prefix="t")
    p = f"pfc{em.n}"
    em.n += 1
    em.w(f"  struct csinn_fc_params *{p} = csinn_alloc_params(sizeof(struct csinn_fc_params), sess);")
    em.w(f"  {p}->units = {units};")
    em.w(f'  {p}->base.name = "fc_{em.n}";')
    em.w(f"  {p}->base.quant_type = CSINN_QUANT_FLOAT32;")
    em.w(f"  csinn_fullyconnected_init({em.var_of[xin]}, {ov}, {wv}, {bv}, {p});")
    calls.append(f"csinn_fullyconnected({em.var_of[xin]}, {ov}, {wv}, {bv}, {p});")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--onnx", required=True)
    ap.add_argument("--input-npz", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--end", type=int, default=-1)
    ap.add_argument("--name", default=None)
    ap.add_argument("--rtol", type=float, default=1e-3)
    ap.add_argument("--atol", type=float, default=1e-4)
    args = ap.parse_args()
    name = args.name or os.path.basename(args.out)
    generate(args.onnx, args.input_npz, args.out, args.start, args.end,
             name, args.rtol, args.atol)


if __name__ == "__main__":
    main()
