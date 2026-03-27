#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import dataclasses
import json
import math
import shutil
import tempfile
import time
import traceback
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence

import numpy as np
import onnx
from onnx import TensorProto, helper, shape_inference
from onnx.reference import ReferenceEvaluator

try:
    import onnxruntime as ort
except ImportError:  # pragma: no cover - optional dependency
    ort = None


class SplitterError(RuntimeError):
    pass


class UnsplittableModelError(SplitterError):
    pass


@dataclasses.dataclass(frozen=True)
class ModelJob:
    key: str
    name: str
    onnx_path: Path
    input_npz_path: Path
    output_dir: Path


@dataclasses.dataclass(frozen=True)
class RangeSlice:
    start: int
    end: int
    weight_bytes: int


@dataclasses.dataclass(frozen=True)
class PartPlan:
    index: int
    start: int
    end: int
    weight_bytes: int
    input_names: List[str]
    output_names: List[str]
    node_names: List[str]


class Logger:
    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self._handle = path.open("a", encoding="utf-8")

    def log(self, message: str) -> None:
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{timestamp}] {message}"
        print(line, flush=True)
        self._handle.write(line + "\n")
        self._handle.flush()

    def close(self) -> None:
        self._handle.close()


class InferenceRunner:
    def __init__(self) -> None:
        self.backend = "onnxruntime" if ort is not None else "onnx.reference"

    def run(self, model_path: Path, feed: Mapping[str, np.ndarray]) -> Dict[str, np.ndarray]:
        normalized = {name: np.asarray(value) for name, value in feed.items()}
        if ort is not None:
            session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
            outputs = session.run(None, normalized)
            output_names = [item.name for item in session.get_outputs()]
            return {name: np.asarray(value) for name, value in zip(output_names, outputs)}

        model = onnx.load(model_path, load_external_data=False)
        evaluator = ReferenceEvaluator(model)
        outputs = evaluator.run(None, normalized)
        output_names = [item.name for item in model.graph.output]
        return {name: np.asarray(value) for name, value in zip(output_names, outputs)}


class GraphAnalyzer:
    def __init__(self, model: onnx.ModelProto) -> None:
        self.model = model
        self.nodes = list(model.graph.node)
        self.init_names = {initializer.name for initializer in model.graph.initializer}
        self.init_sizes = {
            initializer.name: tensor_nbytes(initializer) for initializer in model.graph.initializer
        }
        self.graph_input_names = [
            value.name for value in model.graph.input if value.name not in self.init_names
        ]
        self.graph_output_names = [value.name for value in model.graph.output]
        self.producer_index: Dict[str, int] = {}
        self.node_initializer_names: List[List[str]] = []
        self.node_non_initializer_inputs: List[List[str]] = []
        self.tensor_rank: Dict[str, int] = {}
        self._rank_counter = 0
        self._register_names(self.graph_input_names)
        for node_index, node in enumerate(self.nodes):
            for output_name in node.output:
                if output_name:
                    self.producer_index[output_name] = node_index
                    self._register_names([output_name])
        self._register_names(self.graph_output_names)

        used_initializers: set[str] = set()
        for node in self.nodes:
            initializer_names: List[str] = []
            non_initializer_inputs: List[str] = []
            for input_name in node.input:
                if not input_name:
                    continue
                if input_name in self.init_names:
                    initializer_names.append(input_name)
                    used_initializers.add(input_name)
                else:
                    non_initializer_inputs.append(input_name)
            self.node_initializer_names.append(initializer_names)
            self.node_non_initializer_inputs.append(non_initializer_inputs)
        self.total_weight_bytes = sum(self.init_sizes[name] for name in used_initializers)

    def _register_names(self, names: Iterable[str]) -> None:
        for name in names:
            if name and name not in self.tensor_rank:
                self.tensor_rank[name] = self._rank_counter
                self._rank_counter += 1

    def range_weight_bytes(self, start: int, end: int) -> int:
        seen: set[str] = set()
        total = 0
        for node_index in range(start, end + 1):
            for initializer_name in self.node_initializer_names[node_index]:
                if initializer_name not in seen:
                    seen.add(initializer_name)
                    total += self.init_sizes[initializer_name]
        return total

    def find_max_prefix_under_limit(self, start: int, end: int, limit_bytes: int) -> Optional[int]:
        seen: set[str] = set()
        total = 0
        last_ok: Optional[int] = None
        for node_index in range(start, end + 1):
            for initializer_name in self.node_initializer_names[node_index]:
                if initializer_name not in seen:
                    seen.add(initializer_name)
                    total += self.init_sizes[initializer_name]
            if total <= limit_bytes:
                last_ok = node_index
            else:
                break
        return last_ok

    def split_ranges(self, limit_bytes: int) -> List[RangeSlice]:
        if not self.nodes:
            return [RangeSlice(start=0, end=-1, weight_bytes=self.total_weight_bytes)]
        return self._split_range(0, len(self.nodes) - 1, limit_bytes)

    def _split_range(self, start: int, end: int, limit_bytes: int) -> List[RangeSlice]:
        weight_bytes = self.range_weight_bytes(start, end)
        if weight_bytes <= limit_bytes:
            return [RangeSlice(start=start, end=end, weight_bytes=weight_bytes)]

        split_end = self.find_max_prefix_under_limit(start, end, limit_bytes)
        if split_end is None or split_end < start:
            node = self.nodes[start]
            node_name = node.name or f"node_{start}"
            node_weight = self.range_weight_bytes(start, start)
            raise UnsplittableModelError(
                f"{node_name} at index {start} needs {format_bytes(node_weight)} of weights, "
                f"which is above the limit {format_bytes(limit_bytes)}"
            )

        left = [RangeSlice(start=start, end=split_end, weight_bytes=self.range_weight_bytes(start, split_end))]
        if split_end >= end:
            return left
        return left + self._split_range(split_end + 1, end, limit_bytes)

    def external_inputs(self, start: int, end: int) -> List[str]:
        produced_here = self.produced_set(start, end)
        external_inputs: set[str] = set()
        for node_index in range(start, end + 1):
            for input_name in self.node_non_initializer_inputs[node_index]:
                producer = self.producer_index.get(input_name)
                if input_name not in produced_here and (
                    producer is None or producer < start or producer > end
                ):
                    external_inputs.add(input_name)
        return ordered_names(external_inputs, self.tensor_rank)

    def produced_set(self, start: int, end: int) -> set[str]:
        produced: set[str] = set()
        for node_index in range(start, end + 1):
            for output_name in self.nodes[node_index].output:
                if output_name:
                    produced.add(output_name)
        return produced

    def build_part_plans(self, slices: Sequence[RangeSlice]) -> List[PartPlan]:
        if not self.nodes:
            return [
                PartPlan(
                    index=0,
                    start=0,
                    end=-1,
                    weight_bytes=self.total_weight_bytes,
                    input_names=list(self.graph_input_names),
                    output_names=list(self.graph_output_names),
                    node_names=[],
                )
            ]

        parts: List[Optional[PartPlan]] = [None] * len(slices)
        # Walk backwards so every part carries exactly the tensors needed by the next part.
        required_after: set[str] = set(self.graph_output_names)
        for reversed_index in reversed(range(len(slices))):
            current = slices[reversed_index]
            produced = self.produced_set(current.start, current.end)
            external = set(self.external_inputs(current.start, current.end))

            outputs_set = set(required_after)
            missing = [
                name for name in outputs_set if name not in produced and name not in external
            ]
            if missing:
                missing_preview = ", ".join(sorted(missing)[:5])
                raise SplitterError(
                    f"cannot build carried outputs for nodes {current.start}-{current.end}; "
                    f"missing tensors: {missing_preview}"
                )

            inputs_set = external | (outputs_set - produced)
            node_names = [
                self.nodes[node_index].name or f"node_{node_index}"
                for node_index in range(current.start, current.end + 1)
            ]
            parts[reversed_index] = PartPlan(
                index=reversed_index,
                start=current.start,
                end=current.end,
                weight_bytes=current.weight_bytes,
                input_names=ordered_names(inputs_set, self.tensor_rank),
                output_names=ordered_names(outputs_set, self.tensor_rank),
                node_names=node_names,
            )
            required_after = set(inputs_set)

        first_inputs = parts[0].input_names if parts else []
        unexpected = [name for name in first_inputs if name not in self.graph_input_names]
        if unexpected:
            preview = ", ".join(unexpected[:5])
            raise SplitterError(f"first split part still depends on non-input tensors: {preview}")

        return [part for part in parts if part is not None]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Scan model/*/*.onnx, split oversized models into sequential ONNX submodels, "
            "create chained input npz files, and write results to model_split/."
        )
    )
    parser.add_argument(
        "--model-root",
        type=Path,
        default=Path("model"),
        help="Root directory containing per-model folders with .onnx files.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("model_split"),
        help="Directory where split models, logs, and checkpoints are written.",
    )
    parser.add_argument(
        "--max-weight-kb",
        type=int,
        default=128,
        help="Maximum allowed initializer size per emitted submodel in KB (default: 128).",
    )
    parser.add_argument(
        "--max-weight-bytes",
        type=int,
        default=None,
        help="Optional byte-level override for the maximum allowed weight size.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report predicted split counts without writing submodels or input npz files.",
    )
    parser.add_argument(
        "--no-resume",
        action="store_true",
        help="Ignore checkpoint.json and reprocess every model.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Rewrite output folders even when a matching successful checkpoint entry exists.",
    )
    parser.add_argument(
        "--log-file",
        type=Path,
        default=None,
        help="Optional log path. Defaults to output-root/run.log or output-root/dryrun.log.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    args.model_root = args.model_root.resolve()
    args.output_root = args.output_root.resolve()
    args.resume = not args.no_resume
    args.max_weight_bytes = (
        args.max_weight_bytes if args.max_weight_bytes is not None else args.max_weight_kb * 1024
    )
    if args.max_weight_bytes <= 0:
        raise SystemExit("--max-weight-bytes must be positive")

    args.output_root.mkdir(parents=True, exist_ok=True)
    if args.log_file is None:
        log_name = "dryrun.log" if args.dry_run else "run.log"
        args.log_file = args.output_root / log_name
    else:
        args.log_file = args.log_file.resolve()

    logger = Logger(args.log_file)
    checkpoint_path = args.output_root / "checkpoint.json"
    summary_path = args.output_root / ("dryrun_summary.json" if args.dry_run else "summary.json")
    checkpoint = load_checkpoint(checkpoint_path) if args.resume and not args.dry_run else empty_checkpoint()
    runner = None if args.dry_run else InferenceRunner()

    try:
        jobs = discover_jobs(args.model_root, args.output_root)
        logger.log(
            f"Starting {'dry-run' if args.dry_run else 'run'} for {len(jobs)} model(s) "
            f"with max_weight={format_bytes(args.max_weight_bytes)} "
            f"resume={'on' if args.resume and not args.dry_run else 'off'}"
        )
        if runner is not None:
            logger.log(f"Inference backend: {runner.backend}")

        totals = {
            "passed": [],
            "failed": [],
            "skipped": [],
            "dry_run": [],
            "total_parts": 0,
        }
        run_started = iso_timestamp()
        for index, job in enumerate(jobs, start=1):
            logger.log(f"[{index}/{len(jobs)}] Processing {job.name}")
            result = process_job(
                job=job,
                max_weight_bytes=args.max_weight_bytes,
                dry_run=args.dry_run,
                resume=args.resume,
                force=args.force,
                output_root=args.output_root,
                checkpoint=checkpoint,
                logger=logger,
                runner=runner,
            )
            totals["total_parts"] += int(result.get("part_count", 0))
            if result["status"] == "passed":
                totals["passed"].append(
                    {
                        "model": job.name,
                        "parts": int(result["part_count"]),
                        "weight_bytes": int(result["total_weight_bytes"]),
                    }
                )
            elif result["status"] == "skipped":
                totals["skipped"].append(
                    {
                        "model": job.name,
                        "parts": int(result["part_count"]),
                        "reason": str(result["message"]),
                    }
                )
            elif result["status"] == "dry_run":
                totals["dry_run"].append(
                    {
                        "model": job.name,
                        "parts": int(result["part_count"]),
                        "weight_bytes": int(result["total_weight_bytes"]),
                    }
                )
            else:
                totals["failed"].append(
                    {
                        "model": job.name,
                        "parts": int(result.get("part_count", 0)),
                        "error": str(result["message"]),
                    }
                )

            if not args.dry_run and result["status"] in {"passed", "failed"}:
                checkpoint["models"][job.key] = result["checkpoint_entry"]
                checkpoint["settings"] = {
                    "max_weight_bytes": args.max_weight_bytes,
                    "model_root": str(args.model_root),
                    "output_root": str(args.output_root),
                    "creates_chained_input_npz": True,
                    "verifies_against_original_model": True,
                }
                checkpoint["updated_at"] = iso_timestamp()
                atomic_write_json(checkpoint_path, checkpoint)

        summary = {
            "mode": "dry_run" if args.dry_run else "execute",
            "started_at": run_started,
            "finished_at": iso_timestamp(),
            "model_root": str(args.model_root),
            "output_root": str(args.output_root),
            "max_weight_bytes": args.max_weight_bytes,
            "inference_backend": None if runner is None else runner.backend,
            "models_total": len(jobs),
            "passed_count": len(totals["passed"]),
            "failed_count": len(totals["failed"]),
            "skipped_count": len(totals["skipped"]),
            "dry_run_count": len(totals["dry_run"]),
            "total_parts": totals["total_parts"],
            "passed": totals["passed"],
            "failed": totals["failed"],
            "skipped": totals["skipped"],
            "dry_run": totals["dry_run"],
        }
        atomic_write_json(summary_path, summary)
        log_summary(logger, summary)
        return 0 if not totals["failed"] else 1
    finally:
        logger.close()


def process_job(
    job: ModelJob,
    max_weight_bytes: int,
    dry_run: bool,
    resume: bool,
    force: bool,
    output_root: Path,
    checkpoint: Dict[str, Any],
    logger: Logger,
    runner: Optional[InferenceRunner],
) -> Dict[str, Any]:
    model_signature = file_signature(job.onnx_path)
    input_signature = file_signature(job.input_npz_path)
    checkpoint_entry = checkpoint["models"].get(job.key, {})

    if not dry_run and resume and not force:
        if should_skip(job, checkpoint_entry, max_weight_bytes, output_root):
            message = "checkpoint hit"
            logger.log(f"{job.name}: SKIPPED ({message}) parts={checkpoint_entry.get('part_count', 0)}")
            return {
                "status": "skipped",
                "message": message,
                "part_count": int(checkpoint_entry.get("part_count", 0)),
                "total_weight_bytes": int(checkpoint_entry.get("total_weight_bytes", 0)),
            }

    result: Dict[str, Any] = {
        "status": "failed",
        "message": "",
        "part_count": 0,
        "total_weight_bytes": 0,
    }
    try:
        model = onnx.load(job.onnx_path, load_external_data=False)
        analyzer = GraphAnalyzer(model)
        ranges = analyzer.split_ranges(max_weight_bytes)
        parts = analyzer.build_part_plans(ranges)
        result["part_count"] = len(parts)
        result["total_weight_bytes"] = analyzer.total_weight_bytes

        if dry_run:
            logger.log(
                f"{job.name}: DRY-RUN parts={len(parts)} total_weight={format_bytes(analyzer.total_weight_bytes)}"
            )
            return {
                "status": "dry_run",
                "message": "dry-run only",
                "part_count": len(parts),
                "total_weight_bytes": analyzer.total_weight_bytes,
            }

        if runner is None:
            raise SplitterError("inference backend was not initialized")

        if job.output_dir.exists():
            shutil.rmtree(job.output_dir)
        job.output_dir.mkdir(parents=True, exist_ok=True)

        with tempfile.TemporaryDirectory(prefix="prepared_", dir=str(job.output_dir)) as temp_dir_name:
            prepared_path = Path(temp_dir_name) / f"{job.onnx_path.stem}__prepared.onnx"
            prepared_model = prepare_model_for_extraction(model)
            onnx.save(prepared_model, prepared_path)

            part_records = []
            for part in parts:
                part_base = f"{job.onnx_path.stem}__part{part.index:03d}"
                part_onnx_path = job.output_dir / f"{part_base}.onnx"
                part_input_npz_path = job.output_dir / f"{part_base}_input.npz"

                if part.start <= part.end:
                    onnx.utils.extract_model(
                        str(prepared_path),
                        str(part_onnx_path),
                        part.input_names,
                        part.output_names,
                    )
                else:
                    shutil.copy2(job.onnx_path, part_onnx_path)

                part_model = onnx.load(part_onnx_path, load_external_data=False)
                onnx.checker.check_model(part_model)
                part_input_names = [
                    item.name
                    for item in part_model.graph.input
                    if item.name not in {init.name for init in part_model.graph.initializer}
                ]
                part_output_names = [item.name for item in part_model.graph.output]
                if part_input_names != part.input_names:
                    raise SplitterError(
                        f"{job.name} part {part.index}: input order mismatch "
                        f"{part_input_names} != {part.input_names}"
                    )
                if part_output_names != part.output_names:
                    raise SplitterError(
                        f"{job.name} part {part.index}: output order mismatch "
                        f"{part_output_names} != {part.output_names}"
                    )
                actual_weight_bytes = GraphAnalyzer(part_model).total_weight_bytes
                if actual_weight_bytes > max_weight_bytes:
                    raise SplitterError(
                        f"{job.name} part {part.index}: actual weight {format_bytes(actual_weight_bytes)} "
                        f"still exceeds limit {format_bytes(max_weight_bytes)}"
                    )

                part_records.append(
                    {
                        "index": part.index,
                        "start_node": part.start,
                        "end_node": part.end,
                        "node_count": 0 if part.end < part.start else part.end - part.start + 1,
                        "node_names": part.node_names,
                        "weight_bytes": actual_weight_bytes,
                        "input_names": part.input_names,
                        "output_names": part.output_names,
                        "onnx_path": str(part_onnx_path.relative_to(output_root)),
                        "input_npz_path": str(part_input_npz_path.relative_to(output_root)),
                    }
                )

            original_inputs = load_npz(job.input_npz_path)
            original_feed = require_named_arrays(
                original_inputs,
                analyzer.graph_input_names,
                f"{job.name} original inputs",
            )
            reference_outputs = runner.run(job.onnx_path, original_feed)
            state = require_named_arrays(
                original_inputs,
                parts[0].input_names,
                f"{job.name} part 0 inputs",
            )

            for part_record in part_records:
                part_input = require_named_arrays(
                    state,
                    part_record["input_names"],
                    f"{job.name} part {part_record['index']} input state",
                )
                save_npz(output_root / part_record["input_npz_path"], part_input)
                outputs = runner.run(output_root / part_record["onnx_path"], part_input)
                state = require_named_arrays(
                    outputs,
                    part_record["output_names"],
                    f"{job.name} part {part_record['index']} outputs",
                )

            final_outputs = require_named_arrays(
                state,
                analyzer.graph_output_names,
                f"{job.name} final outputs",
            )
            diff_messages = compare_output_maps(reference_outputs, final_outputs)
            if diff_messages:
                preview = "; ".join(diff_messages[:5])
                raise SplitterError(f"{job.name}: split chain does not match the source model ({preview})")

            manifest = {
                "source_model": str(job.onnx_path),
                "source_input_npz": str(job.input_npz_path),
                "max_weight_bytes": max_weight_bytes,
                "total_weight_bytes": analyzer.total_weight_bytes,
                "part_count": len(part_records),
                "graph_input_names": analyzer.graph_input_names,
                "graph_output_names": analyzer.graph_output_names,
                "inference_backend": runner.backend,
                "parts": part_records,
            }
            manifest_path = job.output_dir / "manifest.json"
            atomic_write_json(manifest_path, manifest)

            artifact_paths = [str(manifest_path.relative_to(output_root))]
            for part_record in part_records:
                artifact_paths.append(part_record["onnx_path"])
                artifact_paths.append(part_record["input_npz_path"])

            logger.log(
                f"{job.name}: PASSED parts={len(part_records)} total_weight={format_bytes(analyzer.total_weight_bytes)}"
            )
            checkpoint_entry = {
                "status": "passed",
                "message": "ok",
                "max_weight_bytes": max_weight_bytes,
                "total_weight_bytes": analyzer.total_weight_bytes,
                "part_count": len(part_records),
                "inference_backend": runner.backend,
                "source_onnx": model_signature,
                "source_input_npz": input_signature,
                "artifacts": artifact_paths,
                "parts": part_records,
                "updated_at": iso_timestamp(),
            }
            return {
                "status": "passed",
                "message": "ok",
                "part_count": len(part_records),
                "total_weight_bytes": analyzer.total_weight_bytes,
                "checkpoint_entry": checkpoint_entry,
            }
    except Exception as exc:
        message = str(exc)
        logger.log(f"{job.name}: FAILED {message}")
        return {
            "status": "failed",
            "message": message,
            "part_count": int(result.get("part_count", 0)),
            "total_weight_bytes": int(result.get("total_weight_bytes", 0)),
            "checkpoint_entry": {
                "status": "failed",
                "message": message,
                "max_weight_bytes": max_weight_bytes,
                "total_weight_bytes": int(result.get("total_weight_bytes", 0)),
                "part_count": int(result.get("part_count", 0)),
                "source_onnx": model_signature,
                "source_input_npz": input_signature,
                "updated_at": iso_timestamp(),
                "traceback": traceback.format_exc(),
            },
        }


def should_skip(
    job: ModelJob,
    checkpoint_entry: Mapping[str, Any],
    max_weight_bytes: int,
    output_root: Path,
) -> bool:
    if not checkpoint_entry:
        return False
    if checkpoint_entry.get("status") != "passed":
        return False
    if int(checkpoint_entry.get("max_weight_bytes", -1)) != max_weight_bytes:
        return False
    if not signature_matches(checkpoint_entry.get("source_onnx"), job.onnx_path):
        return False
    if not signature_matches(checkpoint_entry.get("source_input_npz"), job.input_npz_path):
        return False
    artifacts = checkpoint_entry.get("artifacts") or []
    if not artifacts:
        return False
    return all((output_root / relative_path).exists() for relative_path in artifacts)


def discover_jobs(model_root: Path, output_root: Path) -> List[ModelJob]:
    if not model_root.exists():
        raise SplitterError(f"model root does not exist: {model_root}")

    jobs = []
    for onnx_path in sorted(model_root.glob("*/*.onnx")):
        input_npz_path = onnx_path.parent / "random_input.npz"
        if not input_npz_path.exists():
            raise SplitterError(f"missing random_input.npz beside {onnx_path}")
        relative_dir = onnx_path.parent.relative_to(model_root)
        jobs.append(
            ModelJob(
                key=str(onnx_path.relative_to(model_root)),
                name=str(relative_dir),
                onnx_path=onnx_path,
                input_npz_path=input_npz_path,
                output_dir=output_root / relative_dir,
            )
        )
    return jobs


def prepare_model_for_extraction(model: onnx.ModelProto) -> onnx.ModelProto:
    try:
        prepared = shape_inference.infer_shapes(model)
    except Exception:
        prepared = copy.deepcopy(model)
    known_names = {value.name for value in prepared.graph.value_info}
    extras = []
    for collection in (prepared.graph.input, prepared.graph.output):
        for value_info in collection:
            if value_info.name not in known_names:
                extras.append(copy.deepcopy(value_info))
                known_names.add(value_info.name)
    prepared.graph.value_info.extend(extras)
    return prepared


def compare_output_maps(
    expected: Mapping[str, np.ndarray], actual: Mapping[str, np.ndarray]
) -> List[str]:
    messages = []
    expected_names = list(expected.keys())
    actual_names = list(actual.keys())
    if expected_names != actual_names:
        messages.append(f"output names differ: expected={expected_names} actual={actual_names}")
        return messages

    for name in expected_names:
        expected_value = np.asarray(expected[name])
        actual_value = np.asarray(actual[name])
        if expected_value.shape != actual_value.shape:
            messages.append(
                f"{name}: shape mismatch expected={expected_value.shape} actual={actual_value.shape}"
            )
            continue

        if expected_value.dtype.kind in {"f", "c"} or actual_value.dtype.kind in {"f", "c"}:
            if not np.allclose(
                expected_value,
                actual_value,
                rtol=1e-4,
                atol=1e-5,
                equal_nan=True,
            ):
                if expected_value.size and actual_value.size:
                    max_abs = float(
                        np.max(
                            np.abs(
                                expected_value.astype(np.float64)
                                - actual_value.astype(np.float64)
                            )
                        )
                    )
                else:
                    max_abs = math.inf
                messages.append(f"{name}: floating-point values differ (max_abs={max_abs:.6g})")
        elif not np.array_equal(expected_value, actual_value):
            messages.append(f"{name}: tensor values differ")

    return messages


def require_named_arrays(
    source: Mapping[str, np.ndarray], names: Sequence[str], label: str
) -> Dict[str, np.ndarray]:
    missing = [name for name in names if name not in source]
    if missing:
        preview = ", ".join(missing[:5])
        raise SplitterError(f"{label} is missing tensors: {preview}")
    return {name: np.asarray(source[name]) for name in names}


def load_npz(path: Path) -> Dict[str, np.ndarray]:
    with np.load(path, allow_pickle=False) as data:
        return {name: np.asarray(data[name]) for name in data.files}


def save_npz(path: Path, arrays: Mapping[str, np.ndarray]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez(path, **{name: np.asarray(value) for name, value in arrays.items()})


def ordered_names(names: Iterable[str], rank: Mapping[str, int]) -> List[str]:
    unique = {name for name in names if name}
    return sorted(unique, key=lambda name: (rank.get(name, math.inf), name))


def tensor_nbytes(tensor: TensorProto) -> int:
    if tensor.data_location == TensorProto.EXTERNAL:
        raise SplitterError(f"external tensor data is not supported for {tensor.name}")
    if tensor.raw_data:
        return len(tensor.raw_data)

    try:
        np_dtype = helper.tensor_dtype_to_np_dtype(tensor.data_type)
    except ValueError as exc:
        raise SplitterError(f"unsupported tensor dtype for {tensor.name}: {tensor.data_type}") from exc

    count = int(np.prod(tensor.dims, dtype=np.int64)) if tensor.dims else 1
    return count * int(np.dtype(np_dtype).itemsize)


def load_checkpoint(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return empty_checkpoint()
    with path.open("r", encoding="utf-8") as handle:
        loaded = json.load(handle)
    if not isinstance(loaded, dict):
        raise SplitterError(f"checkpoint file is not a JSON object: {path}")
    loaded.setdefault("models", {})
    loaded.setdefault("settings", {})
    return loaded


def empty_checkpoint() -> Dict[str, Any]:
    return {"version": 1, "settings": {}, "models": {}, "updated_at": iso_timestamp()}


def atomic_write_json(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        dir=str(path.parent),
        delete=False,
    ) as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")
        temp_name = handle.name
    Path(temp_name).replace(path)


def file_signature(path: Path) -> Dict[str, Any]:
    stat = path.stat()
    return {
        "path": str(path),
        "size": int(stat.st_size),
        "mtime_ns": int(stat.st_mtime_ns),
    }


def signature_matches(recorded: Any, path: Path) -> bool:
    if not isinstance(recorded, dict):
        return False
    try:
        current = file_signature(path)
    except FileNotFoundError:
        return False
    return (
        recorded.get("path") == current["path"]
        and int(recorded.get("size", -1)) == current["size"]
        and int(recorded.get("mtime_ns", -1)) == current["mtime_ns"]
    )


def format_bytes(num_bytes: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(num_bytes)
    for unit in units:
        if value < 1024.0 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.2f} {unit}"
        value /= 1024.0
    return f"{num_bytes} B"


def log_summary(logger: Logger, summary: Mapping[str, Any]) -> None:
    logger.log(
        "SUMMARY "
        f"models={summary['models_total']} "
        f"passed={summary['passed_count']} "
        f"failed={summary['failed_count']} "
        f"skipped={summary['skipped_count']} "
        f"dry_run={summary['dry_run_count']} "
        f"total_parts={summary['total_parts']}"
    )
    if summary["passed"]:
        logger.log("PASS LIST")
        for item in summary["passed"]:
            logger.log(
                f"  PASS {item['model']} parts={item['parts']} weight={format_bytes(item['weight_bytes'])}"
            )
    if summary["failed"]:
        logger.log("FAIL LIST")
        for item in summary["failed"]:
            logger.log(f"  FAIL {item['model']} parts={item['parts']} reason={item['error']}")
    if summary["skipped"]:
        logger.log("SKIP LIST")
        for item in summary["skipped"]:
            logger.log(f"  SKIP {item['model']} parts={item['parts']} reason={item['reason']}")
    if summary["dry_run"]:
        logger.log("DRY-RUN LIST")
        for item in summary["dry_run"]:
            logger.log(
                f"  DRYRUN {item['model']} parts={item['parts']} weight={format_bytes(item['weight_bytes'])}"
            )


def iso_timestamp() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


if __name__ == "__main__":
    raise SystemExit(main())
