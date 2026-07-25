#!/usr/bin/env bash
# One-shot repo setup: pulls the csi-nn2 submodule and restores the
# smart_run/work + smart_run/work_par simulation artifacts and the NN model
# artifacts (smart_run/tests/cases/model_compiled, hhb/model) from Baidu Netdisk.
#
# Prerequisites:
#   - BaiduPCS-Go on PATH (brew install baidupcs-go); if not logged in,
#     scripts/baidu_netdisk.py opens a browser to log you in automatically.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="/dev_data/openc906-charles"
TMP_DL="$REPO_ROOT/.netdisk_dl"
NETDISK="python3 $REPO_ROOT/smart_run/scripts/baidu_netdisk.py"

echo "==> [1/3] Pulling csi-nn2 submodule"
git -C "$REPO_ROOT" submodule update --init --recursive csi-nn2

echo "==> [2/3] Downloading tarballs from Baidu Netdisk ($REMOTE_DIR)"
mkdir -p "$TMP_DL"
$NETDISK download \
    "$REMOTE_DIR/work.tar.gz" "$REMOTE_DIR/work_par.tar.gz" \
    "$REMOTE_DIR/model_compiled.tar.gz" "$REMOTE_DIR/hhb_model.tar.gz" \
    --saveto "$TMP_DL"

echo "==> [3/3] Extracting"
tar xzf "$TMP_DL/work.tar.gz" -C "$REPO_ROOT/smart_run"
tar xzf "$TMP_DL/work_par.tar.gz" -C "$REPO_ROOT/smart_run"
tar xzf "$TMP_DL/model_compiled.tar.gz" -C "$REPO_ROOT/smart_run/tests/cases"
tar xzf "$TMP_DL/hhb_model.tar.gz" -C "$REPO_ROOT/hhb"
rm -rf "$TMP_DL"

echo "Done. Restored: smart_run/work, smart_run/work_par, smart_run/tests/cases/model_compiled, hhb/model"
