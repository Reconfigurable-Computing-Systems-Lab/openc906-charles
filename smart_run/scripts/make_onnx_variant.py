#!/usr/bin/env python3
"""Make a reduced-resolution variant of an image-classifier ONNX model.

Rewrites input[0]'s spatial dims (H, W) to --hw, clears any pre-existing
value_info (shape_inference does not overwrite already-populated entries, so
resizing a model that carries stale value_info would emit the old shapes into
model.c while the blob holds new-resolution data), re-runs shape inference,
and writes <out-dir>/mbv2_<hw>.onnx plus a matching random_input.npz.

The npz recipe (np.random.seed(seed); randn) reproduces hhb/model/mbv2_64 and
mbv2_96 bit-exact with the default --seed 7.

Self-check: runs the result through onnxruntime and asserts a finite output.

Usage:
  make_onnx_variant.py --hw 32 --out-dir ../hhb/model/mbv2_32
"""
import argparse
import os

import numpy as np
import onnx
from onnx import shape_inference

DEFAULT_SRC = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..",
    "hhb", "model", "mobilenetv2_100_Opset17_timm",
    "mobilenetv2_100_Opset17_timm.onnx")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--hw", type=int, required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--name", default=None,
                    help="output basename (default mbv2_<hw>)")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()

    model = onnx.load(args.src)
    g = model.graph
    del g.value_info[:]
    inp = g.input[0]
    dims = inp.type.tensor_type.shape.dim
    assert len(dims) == 4, f"expected NCHW input, got {len(dims)} dims"
    n, c = dims[0].dim_value, dims[1].dim_value
    dims[2].dim_value = args.hw
    dims[3].dim_value = args.hw
    model = shape_inference.infer_shapes(model)

    name = args.name or f"mbv2_{args.hw}"
    os.makedirs(args.out_dir, exist_ok=True)
    onnx_path = os.path.join(args.out_dir, f"{name}.onnx")
    onnx.save(model, onnx_path)

    np.random.seed(args.seed)
    x = np.random.randn(n, c, args.hw, args.hw).astype("float32")
    npz_path = os.path.join(args.out_dir, "random_input.npz")
    np.savez(npz_path, **{inp.name: x})

    import onnxruntime as ort
    sess = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])
    outs = sess.run(None, {inp.name: x})
    assert all(np.isfinite(o).all() for o in outs), "non-finite output"
    o0 = outs[0]
    print(f"{onnx_path}: input {[n, c, args.hw, args.hw]} -> "
          f"output {list(o0.shape)}, top-1 = {int(o0.reshape(-1).argmax())}")
    print(npz_path)


if __name__ == "__main__":
    main()
