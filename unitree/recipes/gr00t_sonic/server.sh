#!/usr/bin/env bash
# GR00T PolicyServer，端口 5550，UNITREE_G1_SONIC。不要用 recipes/gr00t/start_gr00t_server.sh（那是 TongBot 16D / 5555）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"
require_gr00t

MODEL_PATH="${1:-${MODEL_PATH:-}}"
PORT="${2:-${POLICY_PORT}}"
DEVICE="${DEVICE:-cuda:0}"

if [ -z "${MODEL_PATH}" ]; then
    echo "用法: bash server.sh /path/to/checkpoint-20000 [5550]" >&2
    exit 1
fi
if [ ! -f "${MODEL_PATH}/config.json" ]; then
    echo "[server] 无效 ckpt: ${MODEL_PATH}" >&2
    exit 1
fi

PY="$(gr00t_python)" || {
    echo "[server] 找不到 Isaac-GR00T python" >&2
    exit 1
}

echo "============================================================"
echo "  GR00T N1.7 PolicyServer  UNITREE_G1_SONIC"
echo "  ckpt:   ${MODEL_PATH}"
echo "  port:   ${PORT}  (TongBot GR00T 是 5555，别撞)"
echo "  device: ${DEVICE}"
echo "============================================================"

cd "${GR00T_DIR}"
exec "${PY}" gr00t/eval/run_gr00t_server.py \
    --model-path "${MODEL_PATH}" \
    --embodiment-tag "${EMBODIMENT_TAG}" \
    --device "${DEVICE}" \
    --host 0.0.0.0 \
    --port "${PORT}"
