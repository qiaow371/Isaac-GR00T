#!/usr/bin/env bash
# 拉与采集/上机配对的 SONIC ONNX（encoder+decoder+obs yaml）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"
require_wbc
cd "${WBC_DIR}"

PY=python3
if [ -x "${WBC_DIR}/.venv_data_collection/bin/python" ]; then
    PY="${WBC_DIR}/.venv_data_collection/bin/python"
elif [ -x "${WBC_DIR}/.venv_inference/bin/python" ]; then
    PY="${WBC_DIR}/.venv_inference/bin/python"
fi

case "${SONIC_VARIANT}" in
    default) FLAGS=() ;;
    v1.1) FLAGS=(--sonic-v1-1) ;;
    low_latency) FLAGS=(--low-latency) ;;
    *) echo "未知 SONIC_VARIANT=${SONIC_VARIANT}" >&2; exit 1 ;;
esac

echo "[download] SONIC_VARIANT=${SONIC_VARIANT} -> ${FLAGS[*]:-(default)}"
"${PY}" download_from_hf.py "${FLAGS[@]}"
