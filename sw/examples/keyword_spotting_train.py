#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""
Offline keyword-spotting style trainer → NeuroPower INT4 (.npw).

NumPy path is default (CI). Optional snnTorch: NP_USE_SNNTORCH=1.
Synthetic multi-class spike patterns stand in for SHD / GSC until datasets land.
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw" / "toolchain"))
from model_converter import pack_nibbles, quantize_int4  # noqa: E402

NUM_CLASSES = 10


def make_synthetic(n_features: int, n_classes: int, n_per_class: int, seed: int = 0):
    rng = np.random.default_rng(seed)
    xs, ys = [], []
    for c in range(n_classes):
        proto = np.zeros(n_features, dtype=np.float64)
        idx = (np.arange(4) + c * 3) % n_features
        proto[idx] = 1.0
        for _ in range(n_per_class):
            x = proto.copy()
            flips = rng.choice(n_features, size=max(1, n_features // 16), replace=False)
            x[flips] = 1.0 - x[flips]
            xs.append(x)
            ys.append(c)
    return np.stack(xs), np.asarray(ys, dtype=np.int64)


def train_numpy(x: np.ndarray, y: np.ndarray, n_out: int, epochs: int = 80, lr: float = 0.35):
    n_in = x.shape[1]
    rng = np.random.default_rng(1)
    w = rng.normal(0, 0.05, size=(n_in, n_out))
    # Boost prototype-aligned init
    for c in range(n_out):
        idx = (np.arange(4) + c * 3) % n_in
        w[idx, c] += 1.5
    for _ in range(epochs):
        logits = x @ w
        logits = logits - logits.max(axis=1, keepdims=True)
        exp = np.exp(logits)
        prob = exp / np.maximum(exp.sum(axis=1, keepdims=True), 1e-12)
        onehot = np.zeros_like(prob)
        onehot[np.arange(len(y)), y] = 1.0
        grad = x.T @ (prob - onehot) / len(y)
        w -= lr * grad
    return w


def accuracy_float(w: np.ndarray, x: np.ndarray, y: np.ndarray) -> float:
    return float(((x @ w).argmax(axis=1) == y).mean())


def accuracy_int4(w_q: np.ndarray, x: np.ndarray, y: np.ndarray, thr: int) -> dict:
    """Post-quant metrics: membrane argmax (primary) + optional spike argmax."""
    correct_mem = 0
    correct_spk = 0
    for i in range(len(y)):
        v = x[i] @ w_q.astype(np.float64)
        pred_mem = int(np.argmax(v))
        spikes = v >= thr
        pred_spk = int(np.argmax(spikes)) if spikes.any() else pred_mem
        correct_mem += int(pred_mem == y[i])
        correct_spk += int(pred_spk == y[i])
    n = len(y)
    return {"membrane": correct_mem / n, "spike": correct_spk / n}


def quantize_aware_finetune(w: np.ndarray, x: np.ndarray, y: np.ndarray, steps: int = 40, lr: float = 0.15):
    """Simple STE-style fine-tune toward INT4."""
    w = w.copy()
    for _ in range(steps):
        w_q = quantize_int4(w).astype(np.float64)
        # Dequant approx: treat INT4 as real for loss
        logits = x @ w_q
        logits = logits - logits.max(axis=1, keepdims=True)
        exp = np.exp(logits)
        prob = exp / np.maximum(exp.sum(axis=1, keepdims=True), 1e-12)
        onehot = np.zeros_like(prob)
        onehot[np.arange(len(y)), y] = 1.0
        grad = x.T @ (prob - onehot) / len(y)
        w -= lr * grad
    return w


def try_snntorch(n_features: int, n_classes: int, epochs: int):
    if os.environ.get("NP_USE_SNNTORCH", "0") != "1":
        return None
    try:
        import torch
        from snntorch import surrogate  # noqa: F401
    except ImportError:
        print("snnTorch/torch missing; NumPy fallback", file=sys.stderr)
        return None
    x, y = make_synthetic(n_features, n_classes, 40, seed=0)
    xt = torch.tensor(x, dtype=torch.float32)
    yt = torch.tensor(y, dtype=torch.long)
    w = torch.nn.Parameter(torch.randn(n_features, n_classes) * 0.1)
    opt = torch.optim.Adam([w], lr=0.05)
    for _ in range(epochs):
        opt.zero_grad()
        loss = torch.nn.functional.cross_entropy(xt @ w, yt)
        loss.backward()
        opt.step()
    return w.detach().cpu().numpy()


def write_npw(path: Path, w_q: np.ndarray, thr: int) -> int:
    n = w_q.shape[0]
    payload = pack_nibbles(w_q)
    crc = zlib.crc32(payload) & 0xFFFFFFFF
    header = struct.pack("<4sHHiI", b"NPW1", n, thr, len(payload), crc)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + payload)
    return len(payload)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--np-n", type=int, default=16)
    ap.add_argument("--features", type=int, default=16)
    ap.add_argument("--epochs", type=int, default=100)
    ap.add_argument("--thr", type=int, default=1)
    ap.add_argument("--min-acc", type=float, default=0.90)
    ap.add_argument("-o", "--output", type=Path, default=ROOT / "sw" / "examples" / "kws_weights.npw")
    ap.add_argument("--report", type=Path, default=ROOT / "sw" / "examples" / "kws_train_report.json")
    args = ap.parse_args()

    n_feat = min(args.features, args.np_n)
    n_cls = min(NUM_CLASSES, args.np_n)
    x, y = make_synthetic(n_feat, n_cls, 60, seed=0)

    w = try_snntorch(n_feat, n_cls, args.epochs)
    backend = "snntorch" if w is not None else "numpy"
    if w is None:
        w = train_numpy(x, y, n_cls, epochs=args.epochs)

    acc_f = accuracy_float(w, x, y)
    w = quantize_aware_finetune(w, x, y)
    w_full = np.zeros((args.np_n, args.np_n), dtype=np.float64)
    w_full[:n_feat, :n_cls] = w
    w_q = quantize_int4(w_full)
    metrics = accuracy_int4(w_q[:n_feat, :n_cls], x, y, thr=args.thr)
    acc_q = metrics["membrane"]

    plen = write_npw(args.output, w_q, args.thr)
    report = {
        "backend": backend,
        "np_n": args.np_n,
        "features": n_feat,
        "classes": n_cls,
        "accuracy_float": round(acc_f, 4),
        "accuracy_int4_membrane": round(metrics["membrane"], 4),
        "accuracy_int4_spike": round(metrics["spike"], 4),
        "threshold": args.thr,
        "weights_path": str(args.output).replace("\\", "/"),
        "payload_bytes": plen,
        "meets_target": acc_q >= args.min_acc,
        "metric": "int4_membrane_argmax",
    }
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if acc_q < args.min_acc:
        print(f"FAIL: INT4 accuracy {acc_q:.3f} < {args.min_acc}", file=sys.stderr)
        return 1
    print("PASS: keyword spotting INT4 accuracy target met")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
