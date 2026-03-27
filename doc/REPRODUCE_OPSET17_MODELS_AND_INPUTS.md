# Reproducing the Opset 17 models and `random_input.npz` files

This document records the exact process used to create the current state of `/root/dev/openc906-charles/hhb`.

## Final state this reproduces

- `602` Opset 17 model entries resolved from `https://onnx.ai/models/`
- `602` new model folders created from that site-backed set
- `604` total `.onnx` files under `hhb/*/*.onnx` after including the pre-existing folders
- `604` total `random_input.npz` files under `hhb/*/random_input.npz`
- about `123.78 GiB` of model data transferred

## Why the process looks like this

Two details mattered:

1. `https://onnx.ai/models/` is client-rendered. Its model list comes from the `onnx/models` GitHub tree plus each directory's `turnkey_stats.yaml`.
2. GitHub raw model URLs now return Git LFS pointer stubs instead of real model binaries. To get the actual `.onnx` files, the download step used the official Hugging Face mirror at `onnxmodelzoo/legacy_models`.

For the `.npz` files, the HHB user guide's npz example shows that each archive entry must be keyed by the model input name exactly, e.g. `np.savez("test.npz", input=t)`.

## Prerequisites

Run everything from:

```bash
cd /root/dev/openc906-charles/hhb
```

The following Python packages were available in the environment used to generate the current result:

- `numpy`
- `onnx` (`1.14.0` was installed)

## Step 1: Download the exact Opset 17 set backed by `onnx.ai/models`

Run this script from `hhb/`:

```bash
python3 -u - <<'PY'
import concurrent.futures
import json
import os
import pathlib
import re
import sys
import time
import urllib.request
from collections import Counter, defaultdict

BASE = pathlib.Path('.').resolve()
HEADERS = {'User-Agent': 'GitHub-Copilot-CLI/1.0.11'}
WORKERS = 8


def req(url, method='GET'):
    return urllib.request.Request(url, headers=HEADERS, method=method)


def fetch_json(url, timeout=120, retries=4):
    last = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req(url), timeout=timeout) as r:
                return json.load(r)
        except Exception as e:
            last = e
            time.sleep(2 ** attempt)
    raise last


def fetch_text(url, timeout=60, retries=4):
    last = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req(url), timeout=timeout) as r:
                return r.read().decode('utf-8', 'replace')
        except Exception as e:
            last = e
            time.sleep(2 ** attempt)
    raise last


def parse_opset(yaml_text):
    opset = 'Not Available'
    inside = False
    for line in yaml_text.splitlines():
        if line.startswith('onnx_model_information:'):
            inside = True
            continue
        if inside:
            if line.startswith('  opset:'):
                opset = line.split(':', 1)[1].strip()
            if not line.startswith('  '):
                inside = False
        if line.startswith('opset:'):
            opset = line.split(':', 1)[1].strip()
    return opset


def discover_paths():
    tree = fetch_json('https://api.github.com/repos/onnx/models/git/trees/main?recursive=1')['tree']
    onnx_by_dir = defaultdict(list)
    yaml_dirs = set()
    for item in tree:
        path = item['path']
        if path.endswith('.onnx') and 'skip/' not in path:
            onnx_by_dir[path.rsplit('/', 1)[0]].append(path)
        elif path.endswith('turnkey_stats.yaml'):
            yaml_dirs.add(path.rsplit('/', 1)[0])
    candidate_dirs = sorted(set(onnx_by_dir) & yaml_dirs)

    def dir_opset(directory):
        url = f'https://raw.githubusercontent.com/onnx/models/main/{directory}/turnkey_stats.yaml'
        try:
            return directory, parse_opset(fetch_text(url))
        except Exception:
            return directory, None

    selected = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=24) as ex:
        for directory, opset in ex.map(dir_opset, candidate_dirs):
            if opset == '17':
                selected.extend(sorted(onnx_by_dir[directory]))
    return sorted(selected)


def sanitize(name):
    name = re.sub(r'[^A-Za-z0-9._-]+', '_', name).strip('._')
    return name or 'model'


def assign_folders(paths):
    stem_counts = Counter(pathlib.Path(p).stem for p in paths)
    used = set()
    mapping = {}
    for path in paths:
        stem = pathlib.Path(path).stem
        dir_name = pathlib.Path(path).parent.name
        raw_path_name = path[:-5].replace('/', '__')
        candidates = [stem, dir_name, raw_path_name]
        if stem_counts[stem] > 1:
            candidates = [dir_name, stem, raw_path_name]
        for candidate in candidates:
            folder = sanitize(candidate)
            if folder not in used:
                used.add(folder)
                mapping[path] = folder
                break
        else:
            i = 2
            while True:
                folder = sanitize(f'{dir_name}__{i}')
                if folder not in used:
                    used.add(folder)
                    mapping[path] = folder
                    break
                i += 1
    return mapping


def head_size(url, timeout=60):
    with urllib.request.urlopen(req(url, method='HEAD'), timeout=timeout) as r:
        size = r.headers.get('Content-Length')
        return int(size) if size and size.isdigit() else 0


def candidate_urls(path):
    filename = pathlib.Path(path).name
    stem = pathlib.Path(path).stem
    dir_name = pathlib.Path(path).parent.name
    urls = [
        f'https://huggingface.co/onnxmodelzoo/legacy_models/resolve/main/{path}',
        f'https://huggingface.co/onnxmodelzoo/{stem}/resolve/main/{filename}',
        f'https://huggingface.co/onnxmodelzoo/{dir_name}/resolve/main/{filename}',
    ]
    deduped = []
    seen = set()
    for url in urls:
        if url not in seen:
            seen.add(url)
            deduped.append(url)
    return deduped


def resolve_url(path):
    last = None
    for url in candidate_urls(path):
        try:
            size = head_size(url)
            return url, size
        except Exception as e:
            last = e
    raise last


def download_one(item):
    path, folder = item
    filename = pathlib.Path(path).name
    target_dir = BASE / folder
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / filename
    tmp = target.with_suffix(target.suffix + '.part')

    url, size = resolve_url(path)
    if target.exists() and (not size or target.stat().st_size == size):
        return 'skipped', str(target)

    last = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req(url), timeout=300) as resp, open(tmp, 'wb') as out:
                while True:
                    chunk = resp.read(1024 * 1024)
                    if not chunk:
                        break
                    out.write(chunk)
            actual = tmp.stat().st_size
            if size and actual != size:
                raise RuntimeError(f'size mismatch for {filename}: expected {size}, got {actual}')
            os.replace(tmp, target)
            return 'downloaded', str(target)
        except Exception as e:
            last = e
            try:
                if tmp.exists():
                    tmp.unlink()
            except Exception:
                pass
            time.sleep(2 ** attempt)
    raise RuntimeError(f'failed to download {path}: {last}')


paths = discover_paths()
mapping = assign_folders(paths)
print(f'resolved_opset17_entries={len(paths)}')

created = 0
skipped = 0
errors = []
with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as ex:
    futures = {ex.submit(download_one, item): item for item in sorted(mapping.items())}
    total = len(futures)
    for idx, fut in enumerate(concurrent.futures.as_completed(futures), 1):
        try:
            status, _ = fut.result()
            if status == 'downloaded':
                created += 1
            else:
                skipped += 1
        except Exception as e:
            errors.append((futures[fut][0], str(e)))
        if idx % 20 == 0 or idx == total:
            print(f'[{idx}/{total}] created={created} skipped={skipped} errors={len(errors)}')

print(f'SUMMARY total={len(paths)} created={created} skipped={skipped} errors={len(errors)}')
if errors:
    for path, err in errors[:20]:
        print('FAILED', path, err)
    raise SystemExit(2)
PY
```

### Expected result for the download step

- `602` Opset 17 entries resolved
- `602` site-backed model folders present after the download step
- around `123.78 GiB` transferred when starting from the original state

## Step 2: Generate `random_input.npz` beside each `.onnx`

The HHB format requirement is simple: the `.npz` archive keys must match the model input names exactly.

The script below:

- walks every `*/*.onnx` file under `hhb/`
- skips folders that already have `random_input.npz`
- reads the real input names, shapes, and dtypes from each ONNX graph
- excludes initializer entries from the input list
- writes a deterministic random input archive beside each model

Generation rules used:

- floating-point inputs: standard normal random values
- integer inputs with names like `mask`, `segment`, or `token_type`: random `0/1`, with the first element forced to `1`
- integer inputs with names containing `position`: `arange(...)`
- other integer inputs: random integers in `[0, 1000)`

Run this script from `hhb/`:

```bash
python3 -u - <<'PY'
import concurrent.futures
import gc
import hashlib
import pathlib
import time

import numpy as np
import onnx
from onnx import TensorProto

BASE = pathlib.Path('.')
WORKERS = 8

DTYPE_MAP = {
    TensorProto.FLOAT: np.float32,
    TensorProto.DOUBLE: np.float64,
    TensorProto.FLOAT16: np.float16,
    TensorProto.BFLOAT16: np.float32,
    TensorProto.INT64: np.int64,
    TensorProto.INT32: np.int32,
    TensorProto.INT16: np.int16,
    TensorProto.INT8: np.int8,
    TensorProto.UINT64: np.uint64,
    TensorProto.UINT32: np.uint32,
    TensorProto.UINT16: np.uint16,
    TensorProto.UINT8: np.uint8,
    TensorProto.BOOL: np.bool_,
}


def rng_for(path, name):
    seed = int.from_bytes(hashlib.sha256(f'{path}:{name}'.encode()).digest()[:8], 'little', signed=False)
    return np.random.default_rng(seed)


def dim_value(dim):
    if dim.HasField('dim_value') and dim.dim_value > 0:
        return dim.dim_value
    return 1


def tensor_shape(tt):
    return tuple(dim_value(d) for d in tt.shape.dim)


def make_array(model_path, input_name, tt):
    shape = tensor_shape(tt)
    elem = tt.elem_type
    np_dtype = DTYPE_MAP.get(elem)
    if np_dtype is None:
        raise RuntimeError(f'unsupported input dtype {TensorProto.DataType.Name(elem)} for {model_path}::{input_name}')
    rng = rng_for(model_path, input_name)
    lname = input_name.lower()

    if elem in (TensorProto.FLOAT, TensorProto.DOUBLE, TensorProto.FLOAT16, TensorProto.BFLOAT16):
        return rng.normal(loc=0.0, scale=1.0, size=shape).astype(np_dtype)

    if elem == TensorProto.BOOL:
        return rng.integers(0, 2, size=shape, dtype=np.uint8).astype(np.bool_)

    if elem in (TensorProto.INT64, TensorProto.INT32, TensorProto.INT16, TensorProto.INT8):
        if 'mask' in lname or 'segment' in lname or 'token_type' in lname:
            data = rng.integers(0, 2, size=shape, dtype=np.int64).astype(np_dtype)
            if data.size:
                data.reshape(-1)[0] = 1
            return data
        if 'position' in lname:
            total = int(np.prod(shape)) if shape else 1
            data = np.arange(total, dtype=np.int64).reshape(shape if shape else ())
            return data.astype(np_dtype)
        high = 64 if elem == TensorProto.INT8 else 1000
        return rng.integers(0, high, size=shape, dtype=np.int64).astype(np_dtype)

    if elem in (TensorProto.UINT64, TensorProto.UINT32, TensorProto.UINT16, TensorProto.UINT8):
        high = 255 if elem == TensorProto.UINT8 else 1000
        return rng.integers(0, high, size=shape, dtype=np.uint64).astype(np_dtype)

    raise RuntimeError(f'unhandled input dtype {TensorProto.DataType.Name(elem)} for {model_path}::{input_name}')


def build_npz(onnx_path):
    out_path = onnx_path.parent / 'random_input.npz'
    if out_path.exists():
        return 'skipped', str(out_path)

    model = onnx.load(onnx_path, load_external_data=False)
    init_names = {i.name for i in model.graph.initializer}
    inputs = [i for i in model.graph.input if i.name not in init_names]
    arrays = {}
    for inp in inputs:
        kind = inp.type.WhichOneof('value')
        if kind != 'tensor_type':
            raise RuntimeError(f'unsupported input kind {kind} for {onnx_path}')
        arrays[inp.name] = make_array(str(onnx_path), inp.name, inp.type.tensor_type)
    np.savez(out_path, **arrays)
    del model, arrays
    gc.collect()
    return 'created', str(out_path)


onnx_files = sorted(BASE.glob('*/*.onnx'))
print(f'onnx_total={len(onnx_files)}')

created = 0
skipped = 0
errors = []
start = time.time()
with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as ex:
    futures = {ex.submit(build_npz, path): path for path in onnx_files}
    total = len(futures)
    for idx, fut in enumerate(concurrent.futures.as_completed(futures), 1):
        try:
            status, _ = fut.result()
            if status == 'created':
                created += 1
            else:
                skipped += 1
        except Exception as e:
            errors.append((str(futures[fut]), str(e)))
        if idx % 20 == 0 or idx == total:
            elapsed = (time.time() - start) / 60.0
            print(f'[{idx}/{total}] created={created} skipped={skipped} errors={len(errors)} elapsed={elapsed:.1f}m')

print(f'SUMMARY total={len(onnx_files)} created={created} skipped={skipped} errors={len(errors)}')
if errors:
    for path, err in errors[:20]:
        print('FAILED', path, err)
    raise SystemExit(2)
PY
```

### Expected result for the input-generation step

From the current tree, this should report:

- `onnx_total=604`
- `created=602`
- `skipped=2`
- `errors=0`

The two skipped archives were the ones that already existed in the tree.

## Step 3: Verify the result

### Coverage and input-key verification

```bash
python3 - <<'PY'
from pathlib import Path
import numpy as np
import onnx

base = Path('.')
onnx_files = sorted(base.glob('*/*.onnx'))
missing = []
bad = []
for onnx_path in onnx_files:
    npz_path = onnx_path.parent / 'random_input.npz'
    if not npz_path.exists():
        missing.append(str(npz_path))
        continue
    model = onnx.load(onnx_path, load_external_data=False)
    init_names = {i.name for i in model.graph.initializer}
    expected = [i.name for i in model.graph.input if i.name not in init_names]
    with np.load(npz_path) as data:
        actual = list(data.files)
        if actual != expected:
            bad.append((str(onnx_path), expected, actual))
print('onnx_total', len(onnx_files))
print('npz_missing', len(missing))
print('key_mismatches', len(bad))
PY
```

Expected output:

```text
onnx_total 604
npz_missing 0
key_mismatches 0
```

### Shape and dtype verification

```bash
python3 - <<'PY'
from pathlib import Path
import numpy as np
import onnx
from onnx import TensorProto

DTYPE_MAP = {
    TensorProto.FLOAT: np.dtype('float32'),
    TensorProto.DOUBLE: np.dtype('float64'),
    TensorProto.FLOAT16: np.dtype('float16'),
    TensorProto.BFLOAT16: np.dtype('float32'),
    TensorProto.INT64: np.dtype('int64'),
    TensorProto.INT32: np.dtype('int32'),
    TensorProto.INT16: np.dtype('int16'),
    TensorProto.INT8: np.dtype('int8'),
    TensorProto.UINT64: np.dtype('uint64'),
    TensorProto.UINT32: np.dtype('uint32'),
    TensorProto.UINT16: np.dtype('uint16'),
    TensorProto.UINT8: np.dtype('uint8'),
    TensorProto.BOOL: np.dtype('bool'),
}

base = Path('.')
shape_bad = []
dtype_bad = []
for onnx_path in sorted(base.glob('*/*.onnx')):
    model = onnx.load(onnx_path, load_external_data=False)
    init_names = {i.name for i in model.graph.initializer}
    with np.load(onnx_path.parent / 'random_input.npz') as data:
        for inp in [i for i in model.graph.input if i.name not in init_names]:
            arr = data[inp.name]
            dims = tuple((d.dim_value if d.HasField('dim_value') and d.dim_value > 0 else 1) for d in inp.type.tensor_type.shape.dim)
            want_dtype = DTYPE_MAP[inp.type.tensor_type.elem_type]
            if arr.shape != dims:
                shape_bad.append((str(onnx_path), inp.name, dims, arr.shape))
            if arr.dtype != want_dtype:
                dtype_bad.append((str(onnx_path), inp.name, str(want_dtype), str(arr.dtype)))
print('shape_mismatches', len(shape_bad))
print('dtype_mismatches', len(dtype_bad))
PY
```

Expected output:

```text
shape_mismatches 0
dtype_mismatches 0
```

## Notes

- The input-generation scan on the current model set found only tensor inputs, with `FLOAT` and `INT64` dtypes and no unknown dimensions.
- A few models have multiple inputs; the scripts above preserve the original input order and names when writing `.npz` archives.
- The generated input data is deterministic because the RNG seed is derived from `onnx_path:input_name`.

## Splitting oversized ONNX models

The repository now includes `split_onnx_models.py` at the `hhb/` root.

It scans `model/*/*.onnx`, checks the total initializer size of each model, and writes results under `model_split/`.
If a model is larger than the configured limit, the script emits a sequential chain of ONNX submodels and a matching input `.npz` for each part.
Part `0` uses the original `random_input.npz`; each later part gets its input `.npz` from the previous part's outputs.

Typical commands:

```bash
# dry-run: report how many submodels each source model would produce
python3 split_onnx_models.py --dry-run

# execute with the default 128 KB limit and resume from checkpoint.json when present
python3 split_onnx_models.py
```

Useful flags:

- `--max-weight-kb 128` or `--max-weight-bytes N` to control the weight limit
- `--output-root model_split` to change the artifact directory
- `--no-resume` to ignore `model_split/checkpoint.json`
- `--force` to rebuild previously generated outputs

Generated artifacts:

- `model_split/run.log` or `model_split/dryrun.log`
- `model_split/checkpoint.json`
- `model_split/summary.json` or `model_split/dryrun_summary.json`
- `model_split/<model_name>/manifest.json`
- `model_split/<model_name>/<model_stem>__partNNN.onnx`
- `model_split/<model_name>/<model_stem>__partNNN_input.npz`
