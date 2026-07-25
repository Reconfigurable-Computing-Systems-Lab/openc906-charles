#!/usr/bin/env python3
"""Split a model into parallel-verifiable segments at articulation points.

An articulation point is a node index after which exactly one tensor produced so
far is still needed downstream (the single forward activation). Cutting only
there guarantees each segment has one external input and one output, so segments
are independent: each is fed its input activation (from a full-model onnxruntime
run) and checked against that node's golden output. This drives onnx2csinn.py to
emit one case dir per segment; the segments together cover every compute node.

Balances segments by MAC count so parallel wall-time is even.

Usage:
  gen_segments.py --onnx M.onnx --input-npz in.npz --prefix mbv2 \
      --out-root <model_compiled> --target-segments 16
Prints the generated case names (one per line) to stdout.
"""
import argparse
import sys

import numpy as np
import onnx
from onnx import shape_inference

import onnx2csinn


def conv_macs(node, vi, init):
    if node.op_type != "Conv":
        # cheap ops ~ output size
        o = node.output[0]
        return int(np.prod([d for d in vi.get(o, [1]) if d > 0]))
    w = node.input[1]
    wdims = None
    for t in init:
        if t.name == w:
            wdims = list(t.dims)
    o = node.output[0]
    od = vi.get(o, [])
    if not wdims or len(od) < 4:
        return 1
    oc, ic_g, kh, kw = wdims
    _, _, oh, ow = od
    return oc * ic_g * kh * kw * oh * ow


def articulation_points(g, init_names):
    nodes = list(g.node)
    N = len(nodes)
    graph_out = {o.name for o in g.output}
    consumers = {}
    for i, nd in enumerate(nodes):
        for x in nd.input:
            if x and x not in init_names:
                consumers.setdefault(x, []).append(i)
    # produced-before tracking
    arts = []
    produced = {}
    for i, nd in enumerate(nodes):
        for o in nd.output:
            if o:
                produced[o] = i
        live = 0
        for o, pi in produced.items():
            cs = consumers.get(o, [])
            if o in graph_out or any(c > i for c in cs):
                live += 1
        if live == 1:
            arts.append(i)
    return arts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--onnx", required=True)
    ap.add_argument("--input-npz", required=True)
    ap.add_argument("--prefix", required=True)
    ap.add_argument("--out-root", required=True)
    ap.add_argument("--target-segments", type=int, default=16)
    ap.add_argument("--rtol", type=float, default=1e-3)
    ap.add_argument("--atol", type=float, default=1e-4)
    args = ap.parse_args()

    model = shape_inference.infer_shapes(onnx.load(args.onnx))
    g = model.graph
    init_names = {t.name for t in g.initializer}
    _, vi = onnx2csinn.infer_shape_map(onnx.load(args.onnx))
    N = len(g.node)

    macs = [conv_macs(nd, vi, g.initializer) for nd in g.node]
    total = sum(macs)
    arts = articulation_points(g, init_names)
    if (N - 1) not in arts:
        arts.append(N - 1)

    # Greedily accumulate MACs; cut at an articulation point once a segment
    # exceeds total/target_segments.
    budget = max(1, total // args.target_segments)
    cuts = []
    acc = 0
    art_set = set(arts)
    for i in range(N):
        acc += macs[i]
        if i in art_set and (acc >= budget or i == N - 1):
            cuts.append(i)
            acc = 0
    if not cuts or cuts[-1] != N - 1:
        cuts.append(N - 1)

    names = []
    start = 0
    for k, end in enumerate(cuts):
        name = f"{args.prefix}_seg{k:02d}"
        onnx2csinn.generate(args.onnx, args.input_npz,
                            f"{args.out_root}/{name}", start, end, name,
                            args.rtol, args.atol)
        names.append(name)
        start = end + 1

    sys.stderr.write(f"{len(names)} segments, ~{budget} MAC budget, total {total} MACs\n")
    for n in names:
        print(n)


if __name__ == "__main__":
    main()
